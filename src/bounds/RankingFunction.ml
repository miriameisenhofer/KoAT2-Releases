open Batteries
open Formulas
open Constraints
open Atoms
open Polynomials
open Program.Types
   
module SMTSolver = SMT.Z3Solver
module Valuation = Valuation.Make(OurInt)
                 
type measure = [ `Cost | `Time ] [@@deriving show, eq]

type constraint_type = [ `Non_Increasing | `Decreasing | `Bounded ]
                     
type t = {
    rank : Location.t -> Polynomial.t;
    decreasing : Transition.t;
    non_increasing : TransitionSet.t;
  }

let one = ParameterPolynomial.one
        
let logger = Logging.(get PRF)  

let rank f = f.rank
           
let decreasing f = f.decreasing
                 
let transitions f = TransitionSet.to_list f.non_increasing

let rank_to_string (locations: Location.t list) (content_to_string: 'a -> string) (pol: Location.t -> 'a) =
  locations
  |> List.enum
  |> Util.enum_to_string (fun l -> Location.to_string l ^ ": " ^ content_to_string (pol l))

let to_string {rank; decreasing; non_increasing} =
  let locations = non_increasing |> TransitionSet.enum |> Program.locations |> List.of_enum |> List.unique ~eq:Location.equal in
  "{rank:" ^ rank_to_string locations Polynomial.to_string rank ^ ";decreasing:" ^ Transition.to_id_string decreasing ^ "}"

let as_parapoly label var =
  match TransitionLabel.update label var with
  (** Correct? In the nondeterministic case we just make it deterministic? *)
  | None -> ParameterPolynomial.of_var var
  | Some p -> ParameterPolynomial.of_polynomial p

(** Farkas Lemma applied to a linear constraint and a cost function given as System Ax<= b, cx<=d. A,b,c,d are the inputs *)
let apply_farkas a_matrix b_right c_left d_right =
  let num_of_fresh = List.length b_right in
  let fresh_vars = Var.fresh_id_list Var.Real num_of_fresh in
  let dual_constr = Constraint.dualise fresh_vars a_matrix c_left in
  let cost_constr = Polynomial.of_coeff_list b_right fresh_vars in
  Constraint.Infix.(dual_constr && cost_constr <= d_right)
  
(** Invokes farkas quantifier elimination. Uses apply_farkas*)
let farkas_transform constr param_atom =
  let vars = VarSet.union (Constraint.vars constr) (ParameterAtom.vars param_atom) in
  let costfunction = ParameterConstraint.lift param_atom in
  let a_matrix = Constraint.get_matrix vars constr in
  let b_right = Constraint.get_constant_vector constr in
  let c_left = List.flatten (ParameterConstraint.get_matrix vars costfunction) in
  (* TODO What, if the list is empty? *)
  let (d_right :: _) = ParameterConstraint.get_constant_vector costfunction in
  apply_farkas a_matrix b_right c_left d_right
  
(** Given a list of variables an affine template-polynomial is generated*)            
let ranking_template (vars: VarSet.t): ParameterPolynomial.t * Var.t list =
  let vars = VarSet.elements vars in
  let num_vars = List.length vars in
  let fresh_vars = Var.fresh_id_list Var.Int num_vars in
  let fresh_coeffs = List.map Polynomial.of_var fresh_vars in
  let linear_poly = ParameterPolynomial.of_coeff_list fresh_coeffs vars in
  let constant_var = Var.fresh_id Var.Int () in
  let constant_poly = ParameterPolynomial.of_constant (Polynomial.of_var constant_var) in
  ParameterPolynomial.(linear_poly + constant_poly),
  List.append fresh_vars [constant_var]
  
module TemplateTable = Hashtbl.Make(Location)

let template_table: ParameterPolynomial.t TemplateTable.t = TemplateTable.create 10

let fresh_coeffs: Var.t list ref = ref []
                                 
let compute_ranking_templates (vars: VarSet.t) (locations: Location.t list): unit =
  let execute () =
    let ins_loc_prf location =
      (* Each location needs its own ranking template with different fresh variables *)
      let (parameter_poly, fresh_vars) = ranking_template vars in
      (location, parameter_poly, fresh_vars)
    in
    let templates = List.map ins_loc_prf locations in
    templates
    |> List.iter (fun (location,polynomial,_) -> TemplateTable.add template_table location polynomial);
    templates
    |> List.map (fun (_,_,fresh_vars)-> fresh_vars)
    |> List.flatten
    |> (fun fresh_vars -> fresh_coeffs := fresh_vars)
  in
  Logger.with_log logger Logger.DEBUG 
                  (fun () -> "compute_ranking_templates", [])
                  ~result:(fun () ->
                    template_table
                    |> TemplateTable.enum
                    |> Util.enum_to_string (fun (location, polynomial) -> Location.to_string location ^ ": " ^ ParameterPolynomial.to_string polynomial)
                  )
                  execute

let decreaser measure t =
  match measure with
  | `Cost -> TransitionLabel.cost t
  | `Time -> Polynomial.one

let transition_constraint measure (constraint_type: constraint_type) (template: Location.t -> ParameterPolynomial.t) ((l,t,l'): Transition.t): Constraint.t =
  let atom =
    match constraint_type with
    | `Non_Increasing -> ParameterAtom.Infix.(template l >= ParameterPolynomial.substitute_f (as_parapoly t) (template l'))
    | `Decreasing -> ParameterAtom.Infix.(template l >= ParameterPolynomial.(of_polynomial (decreaser measure t) + substitute_f (as_parapoly t) (template l')))
    | `Bounded -> ParameterAtom.Infix.(template l >= ParameterPolynomial.of_polynomial (decreaser measure t))      
  in
  farkas_transform (TransitionLabel.guard t) atom
  
let transitions_constraint measure (constraint_type: constraint_type) (template : Location.t -> ParameterPolynomial.t) (transitions : Transition.t list): Constraint.t =
  transitions
  |> List.map (transition_constraint measure constraint_type template)
  |> Constraint.all
  
let find_with measure non_increasing_transitions decreasing_transition =
  let template = TemplateTable.find template_table in

  let non_increasing_constraint =
    transitions_constraint measure `Non_Increasing template (TransitionSet.to_list non_increasing_transitions)
  in
  
  let bounded =
    transition_constraint measure `Bounded template decreasing_transition
  in

  let decreasing =
    transition_constraint measure `Decreasing template decreasing_transition
  in

  Constraint.Infix.(non_increasing_constraint && bounded && decreasing)
  |> Formula.mk
  |> SMTSolver.get_model ~coeffs_to_minimise:!fresh_coeffs
  |> Option.map (fun valuation ->
         let rank location =
           location
           |> template 
           |> ParameterPolynomial.eval_coefficients (fun var -> Valuation.eval_opt var valuation |? OurInt.zero)
         in
         Some {
             rank;
             decreasing = decreasing_transition;
             non_increasing = non_increasing_transitions;
           }
       )
  |? None

module RankingTable = Hashtbl.Make(struct include Transition let equal = Transition.same end)
                    
let time_ranking_table: t RankingTable.t = RankingTable.create 10

let cost_ranking_table: t RankingTable.t = RankingTable.create 10

let ranking_table = function
  | `Time -> time_ranking_table
  | `Cost -> cost_ranking_table
           
let compute measure (scc: TransitionSet.t): unit =
  let execute () =
    scc
    |> TransitionSet.powerset
    |> Enum.iter (fun increasing_transitions ->
           scc
           |> TransitionSet.enum
           |> Enum.iter (fun decreasing_transition ->
                  find_with measure (TransitionSet.add decreasing_transition (TransitionSet.diff scc increasing_transitions)) decreasing_transition
                  |> Option.may (RankingTable.add (ranking_table measure) decreasing_transition)
                )
         ) 
  in
  Logger.with_log logger Logger.DEBUG 
                  (fun () -> "compute_ranking_functions", ["measure", show_measure measure;
                                                           "scc", TransitionSet.to_string scc])
                  ~result:(fun () -> (string_of_int % RankingTable.length % ranking_table) measure)
                  execute

let compute_ measure program =
  program
  |> Program.sccs
  |> Enum.iter (compute measure)
  
let find measure program transition =
  let execute () =
    if TemplateTable.is_empty template_table then
      compute_ranking_templates (Program.vars program) (program |> Program.graph |> TransitionGraph.locations |> LocationSet.to_list);      
    if RankingTable.is_empty (ranking_table measure) then
      compute_ measure program;
    (try
      RankingTable.find_all (ranking_table measure) transition
    with Not_found -> [])
    |> List.rev
  in
  Logger.with_log logger Logger.DEBUG 
                  (fun () -> "find_ranking_functions", ["measure", show_measure measure;
                                                        "transition", Transition.to_id_string transition])
                  ~result:(Util.enum_to_string to_string % List.enum)
                  execute
  
let reset () =
  RankingTable.clear time_ranking_table;
  RankingTable.clear cost_ranking_table;
  TemplateTable.clear template_table
