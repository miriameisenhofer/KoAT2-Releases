open Batteries
open Formulas
open Constraints
open Atoms
open Polynomials
open Program.Types
   
module SMTSolver_ = SMT.Z3Solver
module Valuation = Valuation.Make(OurInt)
                  
type t = {
    pol : Location.t -> Polynomial.t (*This should be a parameter Polynomial, so that it can be used a few times*);
    strictly_decreasing : Transition.t list;
    (*non_increasing : Program_.Transition.t list; not necessary as it contains every transition *)
    transitions : Transition.t list;
  }
  
let logger = Logger.make_log "prf"  

let rank f = f.pol
           
let strictly_decreasing f = f.strictly_decreasing
                          
let transitions f = f.transitions

(* TODO Obsolete? *)
let square (pol1 : Polynomials.Polynomial.t) (pol2: Polynomials.Polynomial.t) = Polynomials.Polynomial.(pol1 * pol2)

let to_string prf = (String.concat ", " (List.map Transition.to_string (strictly_decreasing prf) ))^"\n"

(** Farkas Lemma applied to a linear constraint and a cost function given as System Ax<= b, cx<=d. A,b,c,d are the inputs *)
let apply_farkas a_matrix b_right c_left d_right =
  let num_of_fresh = List.length b_right in
  let fresh_vars = Var.fresh_id_list num_of_fresh in
  let dual_constr = Constraint.dualise fresh_vars a_matrix c_left in
  let cost_constr = Polynomial.of_coeff_list b_right fresh_vars in
  Constraint.Infix.(dual_constr && cost_constr <= d_right)
  
(** Invokes farkas quantifier elimination. Uses apply_farkas*)
let farkas_transform constr param_atom =
(*    print_string (String.concat "-> " ["farkas_transform input";(Constraint.to_string constr);ParameterConstraint.to_string (ParameterConstraint.lift param_atom);"\n"]);*)
  let vars = VarSet.union (Constraint.vars constr) (ParameterAtom.vars param_atom) in
  let costfunction = ParameterConstraint.lift param_atom in
  let a_matrix = Constraint.get_matrix vars constr in
  let b_right = Constraint.get_constant_vector constr in
  let c_left = List.flatten (ParameterConstraint.get_matrix vars costfunction) in
  (* TODO What, if the list is empty? *)
  let (d_right :: _) = ParameterConstraint.get_constant_vector costfunction in
  apply_farkas a_matrix b_right c_left d_right
  
(** Given a list of variables an affine template-polynomial is generated*)            
let ranking_template vars =
  let num_vars = List.length vars in
  let fresh_vars = Var.fresh_id_list num_vars in
  let fresh_coeffs = List.map Polynomial.of_var (fresh_vars) in
  let linear_poly = ParameterPolynomial.of_coeff_list fresh_coeffs vars in
  let constant_var = Var.fresh_id () in
  let constant_poly = ParameterPolynomial.of_constant (Polynomial.of_var constant_var) in
  (ParameterPolynomial.(linear_poly + constant_poly)),(List.append fresh_vars [constant_var])
  
let generate_ranking_template program locations =
  let execute () =
    let vars = VarSet.elements (Program.vars program) in
    let ins_loc_prf location =
      if Program.is_initial_location program location then 
        (location,ParameterPolynomial.one,[]) 
      else 
        let (parameter_poly, var) = ranking_template vars in
        (location, parameter_poly, var)
    in
    let enum_of_prf = List.map ins_loc_prf locations in
    let enum_of_prf_to_copy = List.map (fun (a,b,c)-> (a,b)) enum_of_prf in
    let varlist = List.flatten (List.map (fun (a,b,c)-> c) enum_of_prf) in
    (PrfTable.of_list enum_of_prf_to_copy, varlist)
  in Logger.with_log logger Logger.DEBUG
                     (fun () -> "generated_ranking_template", [])
                     ~result:(fun (parameter_table, _) -> PrfTable.to_string_parapoly parameter_table)
                     execute
                  
                  
let help_update label var =
  let update_var = TransitionLabel.update label var in
  match update_var with
  |None -> ParameterPolynomial.of_var var
  |Some p -> ParameterPolynomial.of_polynomial p
           
let help_non_increasing (initial : bool) (table : ParameterPolynomial.t PrfTable.t) (trans : Transition.t) (vars : Var.t list) =
  let execute () =
    if initial then 
      Constraint.mk_true 
    else
      let (src, trans_label, target) = trans in
      print_string (Location.to_string src);
      print_string (Location.to_string target);
      let start_parapoly =
        try PrfTable.find table src with Not_found -> (print_string (Location.to_string src); raise Not_found) in
      let target_parapoly = PrfTable.find table target in
      let guard = TransitionLabel.guard trans_label in
      let updated_target = ParameterPolynomial.substitute_f (help_update trans_label) target_parapoly in
      let new_atom = ParameterAtom.Infix.(start_parapoly >= updated_target) in
      farkas_transform guard new_atom
  in Logger.with_log logger Logger.DEBUG
                     (fun () -> "help non increasing", ["prf", PrfTable.to_string_parapoly table;
                                                        "transition", Transition.to_id_string trans])
                     ~result:Constraint.to_string
                     execute
  
let help_strict_decrease (initial : bool) (table : ParameterPolynomial.t PrfTable.t) (trans : Transition.t) (vars : Var.t list) =
  if initial then 
    Constraint.mk_true 
  else
    let (src, trans_label, target) = trans in
    let start_parapoly = PrfTable.find table src in
    let target_parapoly = PrfTable.find table target in
    let guard = TransitionLabel.guard trans_label in
    let updated_target = ParameterPolynomial.substitute_f (help_update trans_label) target_parapoly in
    let cost = ParameterPolynomial.of_polynomial (TransitionLabel.cost trans_label) in
    let new_atom = ParameterAtom.mk_ge start_parapoly ParameterPolynomial.(cost + updated_target) in (*here's the difference*)
    farkas_transform guard new_atom

  
let help_boundedness (initial : bool) (table : ParameterPolynomial.t PrfTable.t) (trans : Transition.t) (vars : Var.t list) =
  if initial then 
    Constraint.mk_true 
  else
    let (src, trans_label, _) = trans in
    let start_parapoly = PrfTable.find table src in
    let guard = TransitionLabel.guard trans_label in
    let cost = ParameterPolynomial.of_polynomial (TransitionLabel.cost trans_label) in
    let new_atom = ParameterAtom.Infix.(start_parapoly >= cost) in 
    farkas_transform guard new_atom

  
(**Generates the constraints due to the non increase rule of a polynomial ranking function*)
let get_non_increase_constraints (table : ParameterPolynomial.t PrfTable.t) (program : Program.t) (transitions : Transition.t list) =
  let execute () =
    let variables = VarSet.elements (Program.vars program) in
    transitions
    |> List.map (fun trans -> help_non_increasing (Program.is_initial program trans) table trans variables)
    |> Constraint.all
  in Logger.with_log logger Logger.DEBUG
                     (fun () -> "determined non_incr constraints", ["prf", PrfTable.to_string_parapoly table])
                     ~result:Constraint.to_string
                     execute

(* Generates the strictly decreasing constraints for one single transition wrt to the generated ranking templates*)
let help_strict_oriented program table vars trans (smt,bounded) =
  let execute () =
    let initial = Program.is_initial program trans in
    let curr_smt =
      Constraint.Infix.(smt
                        && help_boundedness initial table trans vars
                        && help_strict_decrease initial table trans vars) in
    let sol = SMTSolver_.satisfiable (Formula.mk curr_smt) in
    if (sol && not(initial)) then
      (curr_smt, List.append bounded [trans])
    else (smt,bounded)
  in Logger.with_log logger Logger.DEBUG 
                     (fun () -> "help strict oriented", ["transition", Transition.to_id_string trans;
                                                         "vars", String.concat ", " (List.map Var.to_string vars)])
                     execute

(*Given a set of transitions the pair (constr,bound) is generated. Constr is the constraint for the ranking function and bounded consists of all strictly oriented transitions *)
let build_strict_oriented (table : ParameterPolynomial.t PrfTable.t) (program : Program.t) (transitions: Transition.t list) (non_incr: Constraint.t) =
  let vars = VarSet.elements (Program.vars program) in
  List.fold_left (fun tuple trans -> help_strict_oriented program table vars trans tuple) (non_incr,[]) transitions

let ranking_function_procedure (program : Program.t) (transitions : Transition.t list) =
  let execute () =
    let (table, fresh_coeffs) = generate_ranking_template program (transitions |> List.enum |> Program.locations |> List.of_enum) in
    let non_incr = get_non_increase_constraints table program transitions in
    let (smt_form , bounded) = build_strict_oriented table program transitions non_incr in
    let model = SMTSolver_.get_model_opt (Formula.mk smt_form) fresh_coeffs in (*(fresh coeffs should be used here)*)
    (PrfTable.map (fun loc prf -> Polynomial.eval_partial (ParameterPolynomial.flatten prf) model) table), bounded
  in Logger.with_log logger Logger.DEBUG 
                     (fun () -> "ranking function procedure", ["transitions", String.concat ", " (List.map Transition.to_id_string transitions)])
                     execute

(** Checks if a transition has already been oriented strictly in a given approximation     *)
let is_already_bounded appr transition =  
  Bound.(equal (Approximation.timebound appr transition) infinity)    
    
let find program appr =
  let transitions =
    program
    |> Program.graph
    |> TransitionGraph.transitions
    |> TransitionSet.to_list
    |> List.filter (is_already_bounded appr) in
  let execute () =
    let (table,bounded) = ranking_function_procedure program transitions in
    {   pol = PrfTable.find table;
        strictly_decreasing = bounded;
        transitions = transitions;
    }
  in Logger.with_log logger Logger.DEBUG 
                     (fun () -> "find ranking function", ["prf", (PrfTable.to_string_poly (Tuple2.first (ranking_function_procedure program transitions)))])
                     ~result:to_string
                     execute
