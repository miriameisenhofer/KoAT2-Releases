open Batteries

(** Provides a unified interface of the parser and lexer for transition graphs.
    With this module it is possible to abstract from the details of parsing and lexing *)

(** Constructs a reader for the given transition graph *)
(*module Make(G : Parseable.Program) :
  sig*)
    module Parser_ = Parser
    module Lexer_  = Lexer

    exception Error of string
                                 
    val read_file : string -> Program.t

    val read_transitiongraph : string -> Program.t

    val read_formula : string -> Formula.PolynomialFormula.t

    val read_constraint : string -> Constraints.PolynomialConstraint.t
      
    val read_atom : string -> Atoms.PolynomialAtom.t

    val read_polynomial : string -> Polynomial.t

    val read_bound : string -> Bound.t
      
(*  end*)
