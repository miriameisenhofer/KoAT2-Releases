open Batteries
open Program.Types
open Polynomials
open Atoms
open Constraints
open PolyTypes

module Koat2Apron =
  struct

    (** Converts a koat variable to its apron equivalent. *)
    let var_to_apron: Var.t -> Apron.Var.t =
      Apron.Var.of_string % Var.to_string
      
    (** Converts a koat variable set to its apron equivalent. *)
    let vars_to_apron: VarSet.t -> Apron.Var.t array =
      VarSet.map_to_array var_to_apron
      
    (** Converts a koat integer to its apron equivalent. *)
    (** TODO Usage of OurInt.to_int breaks usage of big_int *)
    let const_to_apron: OurInt.t -> Apron.Coeff.t =
      Apron.Coeff.s_of_int % OurInt.to_int
      
    (** Converts a koat polynomial to its apron equivalent. *)
    let poly_to_apron (environment: Apron.Environment.t) (poly: Polynomial.t): Apron.Texpr1.t =
      (* TODO Texpr1.Up: Round in which direction? *) 
      let open Apron in 
      Polynomial.fold
        ~const:(fun c ->
          Texpr1.Cst (const_to_apron c)
        )
        ~var:(fun v ->
          Texpr1.Var (var_to_apron v)
        )
        ~neg:(fun expr ->
          Texpr1.Unop (Texpr1.Neg, expr, Texpr1.Int, Texpr1.Up)
        )
        ~plus:(fun expr1 expr2 ->
          Texpr1.Binop (Texpr1.Add, expr1, expr2, Texpr1.Int, Texpr1.Up)
        )
        ~times:(fun expr1 expr2 ->
          Texpr1.Binop (Texpr1.Mul, expr1, expr2, Texpr1.Int, Texpr1.Up)
        )
        ~pow:(fun expr n ->
          Enum.repeat ~times:n expr
          |> Enum.fold
               (fun result expr -> Texpr1.Binop (Texpr1.Mul, result, expr, Texpr1.Int, Texpr1.Up))
               (Texpr1.Cst (const_to_apron OurInt.one))
        )
        poly
      |> Apron.Texpr1.of_expr environment
      
    (** Converts a koat atom to its apron equivalent *)
    let atom_to_apron (environment: Apron.Environment.t) (atom: Atom.t): Apron.Tcons1.t =
      let open Apron in
      Atom.fold
        ~subject:(poly_to_apron environment)
        (* We have a<=b, Apron uses form c>=0, therefore we need 0<=b-a *)
        ~le:(fun expr1 expr2 -> Tcons1.make (Texpr1.binop Texpr1.Sub expr2 expr1 Texpr1.Int Texpr1.Up) Tcons1.SUPEQ)
        atom
      
    (** Converts a koat constraint to its apron equivalent *)
    let constraint_to_apron (environment: Apron.Environment.t) (constr: Constraint.t): Apron.Tcons1.earray =
      let open Apron in
      let single_constraints =
        constr
        |> Constraint.atom_list
        |> List.map (atom_to_apron environment)
        |> Array.of_list (* Pretty dump, but more readable *)
      in
      let constraints =
        Tcons1.array_make environment (Array.length single_constraints)
      in
      (* Copy the array to an apron array, this loop seems to be the only way *)
      for i=0 to Array.length single_constraints - 1 do
        Tcons1.array_set constraints i (Array.get single_constraints i)
      done;
      constraints
      
  end
  
module Apron2Koat =
  struct

    (** Converts an apron variable to its koat equivalent. *)
    let var_from_apron: Apron.Var.t -> Var.t =
      Var.of_string % Apron.Var.to_string
    
    (** Converts an apron variable set to its koat equivalent. *)
    let vars_from_apron: Apron.Var.t array -> VarSet.t =
      VarSet.of_enum % Array.enum % Array.map var_from_apron

    (** Converts an apron integer to its koat equivalent. *)
    (** TODO Usage of OurInt.to_int breaks usage of big_int *)
    let const_from_apron (coeff: Apron.Coeff.t): OurInt.t =
      let open Apron in
      match coeff with
      | Coeff.Scalar (Scalar.Float float) ->
         OurInt.of_int (int_of_float float)
      | Coeff.Scalar _ -> raise (Failure "Apron special floats are not allowed!")
      | Coeff.Interval _ -> raise (Failure "Apron Intervals are not allowed!")
      
    (** Converts an apron polynomial to its koat equivalent. *)
    let poly_from_apron (expr: Apron.Texpr1.t): Polynomial.t =
      let open Apron in
      let rec expr_to_poly = function
        | Texpr1.Cst coeff -> Polynomial.of_constant (const_from_apron coeff)
        | Texpr1.Var var -> Polynomial.of_var (var_from_apron var)
        | Texpr1.Unop (Texpr1.Neg, expr, Texpr1.Int, _) -> Polynomial.neg (expr_to_poly expr)
        | Texpr1.Unop _ -> raise (Failure "Usage of not supported apron unary operator!")
        | Texpr1.Binop (Texpr1.Add, expr1, expr2, Texpr1.Int, _) -> Polynomial.add (expr_to_poly expr1) (expr_to_poly expr2)
        | Texpr1.Binop (Texpr1.Sub, expr1, expr2, Texpr1.Int, _) -> Polynomial.sub (expr_to_poly expr1) (expr_to_poly expr2)
        | Texpr1.Binop (Texpr1.Mul, expr1, expr2, Texpr1.Int, _) -> Polynomial.mul (expr_to_poly expr1) (expr_to_poly expr2)
        | Texpr1.Binop _ -> raise (Failure "Usage of not supported apron binary operator!")
      in
      expr
      |> Apron.Texpr1.to_expr
      |> expr_to_poly
      
    (** Converts an apron atom to its koat equivalent *)
    let atom_from_apron (single_constraint: Apron.Tcons1.t): Constraint.t =
      let open Apron in
      let comparator = match Tcons1.get_typ single_constraint with
      | Tcons1.EQ -> Constraint.mk_eq
      | Tcons1.SUPEQ -> Constraint.mk_ge
      | Tcons1.SUP -> Constraint.mk_gt
      | Tcons1.DISEQ -> raise (Failure "Usage of not supported apron disequality!")
      | Tcons1.EQMOD _ -> raise (Failure "Usage of not supported apron modequality!")
      in
      comparator (poly_from_apron (Tcons1.get_texpr1 single_constraint)) Polynomial.zero

    (** Converts a koat constraint to its apron equivalent *)
    let constraint_from_apron (constraint_array: Apron.Tcons1.earray): Constraint.t =
      (* If someone still needs a reason to switch to functional programming, here it is. *)
      let result = ref [] in       
      for i=0 to Apron.Tcons1.array_length constraint_array - 1 do
        result := atom_from_apron (Apron.Tcons1.array_get constraint_array i)::!result
      done;
      Constraint.all !result

  end
    
let transform_program program =

  let open Koat2Apron in
  let open Apron2Koat in
  
  (** Creates the apron environment where all program variables are integer variables. *)
  let environment: Apron.Environment.t =
    Apron.Environment.make (vars_to_apron (Program.vars program)) [||]
  in

  (** The manager defines the abstract domain of the variables.
      The octagon domain searches for something like +-x +-y <= b *)
  let manager =
    Oct.manager_alloc ()
  in

  (** Applies the guard to the abstract value, reducing its size. *)
  let apply_guard (guard: TransitionLabel.Guard.t) (abstract: 'a Apron.Abstract1.t): 'a Apron.Abstract1.t =
    guard
    |> constraint_to_apron environment
    |> Apron.Abstract1.meet_tcons_array manager abstract
  in

  (** Applies the update to the abstract value. *)
  let apply_update (vars: VarSet.t) (update: Var.t -> Polynomial.t Option.t) (abstract: 'a Apron.Abstract1.t): 'a Apron.Abstract1.t =
    (* TODO Reset the temporary variables from the new design *)
    let assignments =
      vars
      |> VarSet.to_array
      |> Array.map update
      |> Array.map (Option.map (poly_to_apron environment))
      |> Array.map Option.get (* TODO With the new design an update will be always defined *)
    in
    Apron.Abstract1.assign_texpr_array manager abstract (vars_to_apron vars) assignments None
  in

  (** Applies the transition to the abstract value.
      First, it applies the guard and then the update. *)
  let apply_transition ((l,t,l'): Transition.t) (abstract: 'a Apron.Abstract1.t): 'a Apron.Abstract1.t =
    abstract
    |> apply_guard (TransitionLabel.guard t)
    |> apply_update (Program.vars program) (TransitionLabel.update t)
  in

  let module LocationMap = Map.Make(Location) in

  (** The bottom element of the static analysis for the whole program.
      The values at the start location are defined to be not restricted in any way.
      All other values at other program locations are undefined in the beginning.
      This will change through assignments in the program. *)
  let bottom: ('a Apron.Abstract1.t) LocationMap.t =
    program
    |> Program.graph
    |> TransitionGraph.locations
    |> LocationSet.enum
    |> Enum.map (fun location ->
           if Program.is_initial_location program location then
             (location, Apron.Abstract1.top manager environment)
           else
             (location, Apron.Abstract1.bottom manager environment)
         )
    |> LocationMap.of_enum
  in

  (** Recomputes the abstract value for the single location.
      For this purpose, all incoming transitions are considered and their updated abstract value meet together in a union. *)
  let recompute_location (location: Location.t) (program_abstract :('a Apron.Abstract1.t) LocationMap.t): ('a Apron.Abstract1.t) LocationMap.t =
    location
    |> TransitionGraph.pred_e (Program.graph program)
    |> List.map (fun (l,t,l') ->
           program_abstract
           |> LocationMap.find l 
           |> apply_transition (l,t,l')
         )
    |> Array.of_list
    |> Apron.Abstract1.join_array manager
    |> (fun new_abstract -> LocationMap.modify location (Apron.Abstract1.meet manager new_abstract) program_abstract) 
  in

  let find_fixpoint (program_abstract :('a Apron.Abstract1.t) LocationMap.t): ('a Apron.Abstract1.t) LocationMap.t =
    (* TODO At this point, we have a abstract bottom element for the whole program and a function, which can recompute the abstract value for a single location.
       Now it is important, to find a good sequence of locations, such that the recomputation of all locations comes as early as possible to a fixpoint.  *)
    (* TODO Maybe it is better to recompute transitions instead of locations. *)
    program
    |> Program.graph
    |> TransitionGraph.locations
    |> LocationSet.enum
    |> Enum.map (fun location -> (location, Apron.Abstract1.top manager environment)) (* TODO Add the moment we just use a dummy safe overapproximation. *)
    |> LocationMap.of_enum
  in
  
  (** Converts a value of the abstract domain into a koat constraint which acts as an invariant. *)
  let extract_invariant (abstract: 'a Apron.Abstract1.t): Constraint.t =
    abstract
    |> Apron.Abstract1.to_tcons_array manager
    |> constraint_from_apron 
  in

  (** Determines for each location its invariant constraint and filters locations, which does not have an additional invariant. *)
  let invariants =
    bottom
    |> find_fixpoint
    |> LocationMap.map extract_invariant
    |> LocationMap.filterv (not % Constraint.is_true)
  in

  if LocationMap.is_empty invariants then
    MaybeChanged.same program
  else
    program
    |> LocationMap.fold Program.add_invariant invariants
    |> MaybeChanged.changed (* TODO Actually, we should check if the new invariant is already implied and only then say, that it is changed. *)