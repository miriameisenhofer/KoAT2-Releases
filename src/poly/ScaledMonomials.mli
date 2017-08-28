open Batteries

(** Internal *)
module Make
         (Var : PolyTypes.ID)
         (Value : Number.Numeric)
       : PolyTypes.ScaledMonomial with module Var = Var
                         and module Value = Value
                         and module Valuation_ = Valuation.Make(Var)(Value)
                         and module RenameMap_ = RenameMap.Make(Var)
                         and type monomial = Monomials.Make(Var)(Value).t