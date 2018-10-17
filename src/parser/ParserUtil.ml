open Batteries
open Formulas
open Polynomials
open ProgramTypes
   
let mk_transition lhs (cost: Polynomial.t) (rhs: string * ((string * (TransitionLabel.UpdateElement.t list)) list)) (formula: Formula.t) (vars:Var.t list): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
	 (Location.of_string (Tuple2.first lhs),
          TransitionLabel.mk
            ~cost:cost
            ~com_kind:(Tuple2.first rhs)
            ~targets:(Tuple2.second rhs)
            ~patterns:(List.map Var.of_string (Tuple2.second lhs))
            ~guard:constr,
          (Location.of_string (Tuple2.first (List.hd (Tuple2.second rhs)))))
       )
  |> List.map (fun (l,t,l') -> (l,t ~vars,l'))

  (*So far recursion cannot be parsed, therefore the location is taken as the head of the list as non singleton lists yield an exception*)
  let mk_transition_prob lhs (cost: Polynomial.t) (rhs: (OurFloat.t * string * ((string * (TransitionLabel.UpdateElement.t list)) list)) list) (formula: Formula.t) (vars:Var.t list): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
          let id = unique() in
          List.map (fun (prob, comkind, targets) ->
            (Location.of_string (Tuple2.first lhs),
              TransitionLabel.mk_prob
                ~cost:cost
                ~com_kind:comkind
                ~targets:targets
                ~patterns:(List.map Var.of_string (Tuple2.second lhs))
                ~guard:constr
                ~id:id
                ~probability:prob,
              (Location.of_string (Tuple2.first (List.hd targets))))
        ) rhs)
  |> List.concat
  |> List.map (fun (l,t,l') -> (l,t ~vars,l'))
  
let cartesian l l' = 
  List.concat (List.map (fun e -> List.map (fun e' -> (e,e')) l') l)

let default_vars =
  ["x"; "y"; "z"; "u"; "v"; "w"; "p"; "q"]
  |> List.map Var.of_string

let mk_transition_simple (start: string) (cost: Polynomial.t) (rhs: string * (string * TransitionLabel.UpdateElement.t list) list) (formula: Formula.t): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
	 (Location.of_string start,
          TransitionLabel.mk
            ~com_kind:(Tuple2.first rhs)
            ~targets:(Tuple2.second rhs)
            ~patterns:default_vars
            ~guard:constr 
            ~cost:cost
            ~vars:default_vars, (Location.of_string (Tuple2.first (List.hd (Tuple2.second rhs)))))
       )
       
let mk_transition_simple_prob (start: string) (cost: Polynomial.t) (rhs: (OurFloat.t * string * (string * TransitionLabel.UpdateElement.t list) list) list) (formula: Formula.t): Transition.t list =
  formula
  |> Formula.constraints
  |> List.map (fun constr ->
          List.map (fun (prob, comkind, targets) ->
          let id = unique() in
          (Location.of_string start,
            TransitionLabel.mk_prob
              ~cost:cost
              ~com_kind:comkind
              ~targets:targets
              ~patterns:default_vars
              ~guard:constr
              ~vars:default_vars
              ~id:id
              ~probability:prob,
            (Location.of_string (Tuple2.first (List.hd targets))))
       ) rhs)
  |> List.concat

       
let mk_program_simple (transitions: Transition.t list): Program.t =
  transitions
  |> List.hd
  |> Transition.src
  |> Program.from transitions

let mk_program goal start vars (transitions: Transition.t list): Program.t =
  Program.from transitions start
