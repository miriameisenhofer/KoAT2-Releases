open Batteries
open PolyTypes

module type ParseablePolynomialConstraintsAtom =
  sig
    type t
    module Polynomial_ : ParseablePolynomial
    val mk_gt : Polynomial_.t -> Polynomial_.t -> t
    val mk_ge : Polynomial_.t -> Polynomial_.t -> t
    val mk_lt : Polynomial_.t -> Polynomial_.t -> t
    val mk_le : Polynomial_.t -> Polynomial_.t -> t
    val mk_eq : Polynomial_.t -> Polynomial_.t -> t
    val mk_neq : Polynomial_.t -> Polynomial_.t -> t
    val to_string : t -> string
  end
  
module type PolynomialConstraintsAtom =
  sig
        module Var : ID
        module Value : Number.Numeric
        module Polynomial_ : (Polynomial with module Var = Var and module Value = Value)
             
        type t
           
        (*getting information*)
        val get_first_arg : t -> Polynomial_.t
        val get_second_arg : t -> Polynomial_.t
        
        (*creation*)
        val mk_gt : Polynomial_.t -> Polynomial_.t -> t
        val mk_ge : Polynomial_.t -> Polynomial_.t -> t
        val mk_lt : Polynomial_.t -> Polynomial_.t -> t
        val mk_le : Polynomial_.t -> Polynomial_.t -> t
        val mk_eq : Polynomial_.t -> Polynomial_.t -> t
        val mk_neq : Polynomial_.t -> Polynomial_.t -> t
        
        (*boolean tests*)
        val is_gt : t -> bool
        val is_ge : t -> bool
        val is_lt : t -> bool
        val is_le : t -> bool
        val is_eq : t -> bool
        val is_neq : t -> bool
        val is_same_constr : t -> t -> bool
        val is_inverted_constr : t -> t -> bool
        val is_redundant : t -> t -> bool
        val (==) : t -> t -> bool
        
        (*export*)
        val to_string : t -> string
        val to_z3 : Z3.context -> t -> Z3.Expr.expr
        val get_variables : t -> Var.t list
        val rename_vars : t -> Polynomial_.RenameMap_.t -> t
        val eval_bool : t -> Polynomial_.Valuation_.t -> bool
    end
