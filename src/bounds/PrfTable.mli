open Batteries

include module type of Hashtbl.Make(Program.TransitionGraph.V)

type table = (Polynomials.ParameterPolynomial.t) t

val to_string : table -> string