open Batteries
open Formulas
open Polynomials
open BoundsInst
open ProgramTypes

let mk_transition trans_id_counter lhs (cost: Polynomial.t) gtcost (rhs: string * ((string * (TransitionLabel.UpdateElement.t list)) list)) (formula: Formula.t) (vars:Var.t list): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
	 (Location.of_string_and_arity (Tuple2.first lhs) (List.length @@ Tuple2.second lhs),
          TransitionLabel.mk
            trans_id_counter
            ~cvect:(cost, gtcost |> RealPolynomial.of_intpoly |> RealBound.of_poly)
            ~com_kind:(Tuple2.first rhs)
            ~targets:(Tuple2.second rhs)
            ~patterns:(List.map Var.of_string (Tuple2.second lhs))
            ~guard:constr,
          (Location.of_string_and_arity (Tuple2.first (List.hd (Tuple2.second rhs))) (List.length @@ Tuple2.second @@ List.hd @@ Tuple2.second rhs)))
       )
  |> List.map (fun (l,t,l') -> (l,t ~vars,l'))

  (*So far recursion cannot be parsed, therefore the location is taken as the head of the list as non singleton lists yield an exception*)
  let mk_transition_prob trans_id_counter lhs (cost: Polynomial.t) gtcost (rhs: (OurFloat.t * string * ((string * (TransitionLabel.UpdateElement.t list)) list)) list) (formula: Formula.t) (vars:Var.t list): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
          let id = TransitionLabel.get_unique_gt_id trans_id_counter () in
          List.map (fun (prob, comkind, targets) ->
            (Location.of_string_and_arity (Tuple2.first lhs) (List.length @@ Tuple2.second lhs),
              TransitionLabel.mk_prob
                trans_id_counter
                ~cvect:(cost, gtcost |> RealPolynomial.of_intpoly |> RealBound.of_poly)
                ~com_kind:comkind
                ~targets:targets
                ~patterns:(List.map Var.of_string (Tuple2.second lhs))
                ~guard:constr
                ~gt_id:id
                ~probability:prob,
              (Location.of_string_and_arity (Tuple2.first (List.hd targets)) (List.length @@ Tuple2.second @@ List.hd targets)))
        ) rhs)
  |> List.concat
  |> List.map (fun (l,t,l') -> (l,t ~vars,l'))

let cartesian l l' =
  List.concat (List.map (fun e -> List.map (fun e' -> (e,e')) l') l)

let default_vars =
  ["x"; "y"; "z"; "u"; "v"; "w"; "p"; "q"]
  |> List.map Var.of_string


module VarMap = Map.Make(Var)

let mk_transition_simple trans_id_counter (start: string) (cost: Polynomial.t) gtcost (rhs: string * (string * TransitionLabel.UpdateElement.t list) list) (formula: Formula.t): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
	 (Location.of_string_and_arity start (List.length default_vars),
          TransitionLabel.make
            trans_id_counter
            ~cvect:(cost, RealPolynomial.of_intpoly gtcost |> RealBound.of_poly)
            (Tuple2.first rhs)
            ~input_vars_ordered:default_vars
            ~update:(
              let target = Tuple2.second @@ List.hd @@ Tuple2.second rhs in
              let (given_vars, remaining_vars) =
                List.split_at (List.length target) default_vars
              in
              VarMap.of_enum @@ Enum.combine
                (List.enum given_vars) (List.enum target)
              |> List.fold_right (fun v -> VarMap.add v (TransitionLabel.UpdateElement.Poly (Polynomial.of_var v))) remaining_vars
            )
            ~update_vars_ordered:default_vars
            ~guard:constr
          , (Location.of_string_and_arity (Tuple2.first (List.hd (Tuple2.second rhs))) (List.length default_vars))
         )
       )

let mk_transition_simple_prob trans_id_counter (start: string) (cost: Polynomial.t) gtcost (rhs: (OurFloat.t * string * (string * TransitionLabel.UpdateElement.t list) list) list) (formula: Formula.t): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
          List.map (fun (prob, comkind, targets) ->
          let target = List.hd targets in
          let id = TransitionLabel.get_unique_gt_id trans_id_counter () in
          (Location.of_string_and_arity start (List.length default_vars),
            TransitionLabel.make_prob
              trans_id_counter
              ~cvect:(cost, RealPolynomial.of_intpoly gtcost |> RealBound.of_poly)
              comkind
              ~input_vars_ordered:default_vars
              ~update:(
                let (given_vars, remaining_vars) =
                  List.split_at (List.length @@ Tuple2.second target) default_vars
                in
                VarMap.of_enum @@ Enum.combine
                  (List.enum given_vars) (List.enum (Tuple2.second target))
                |> List.fold_right
                    (fun v -> VarMap.add v (TransitionLabel.UpdateElement.Poly (Polynomial.of_var v)))
                    remaining_vars
              )
              ~update_vars_ordered:default_vars
              ~guard:constr
              ~gt_id:id
              ~probability:prob,
            (Location.of_string_and_arity (Tuple2.first (List.hd targets)) (List.length default_vars)))
       ) rhs)
  |> List.concat


let mk_program_simple (transitions: Transition.t list): Program.t =
  transitions
  |> List.hd
  |> Transition.src
  |> Program.from transitions

let mk_program goal start vars (transitions: Transition.t list): Program.t =
  Program.from transitions start

let ourfloat_of_decimal_string (str: string): OurFloat.t =
  (* Check if fraction *)
  if String.contains str '[' then
    OurFloat.of_string (String.strip ~chars:"[]" str)
  else
    let str_before_point = String.split str ~by:(".") |> Tuple2.first in
    let str_after_point = String.split str ~by:(".") |> Tuple2.second in
    let numerator =
      if str_after_point = "" then OurFloat.zero else OurFloat.of_string str_after_point
    in
    let denominator =
      OurFloat.pow (OurFloat.of_int 10) (String.length str_after_point)
    in
    let fractional = if str_after_point = "" then OurFloat.zero else OurFloat.( numerator/denominator ) in
    let leading = if str_before_point = "" then OurFloat.zero else OurFloat.of_string str_before_point in
    OurFloat.(leading + fractional)
