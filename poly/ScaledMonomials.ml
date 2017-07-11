open Batteries
open ID
open Big_int.Infix
open Evaluable
   
module type ScaledMonomial =
  sig
    type t
    type power
    type monomial
    include Evaluable with type t := t
    val make : value -> monomial -> t
    val lift : monomial -> t
    val simplify : t -> t
    val mult : t -> t -> t
    val mult_with_const : value -> t -> t
    val one : t
    val coeff : t -> value
    val monomial : t -> monomial
  end

module MakeScaledMonomial(Var : ID) =
  struct    
    module VariableTerm = Variables.MakeVariableTerm(Var)
    module Valuation = Valuation.MakeValuation(Var)
    module RenameMap = Map.Make(Var)
    module Power = Powers.MakePower(Var)
    module Monomial = Monomials.MakeMonomial(Var)

    type t = 
      {
        coeff : Valuation.value; 
        mon :   Monomial.t;
      }    
    type value = Valuation.value
    type valuation = Valuation.t
    type var = Var.t
    type rename_map = var RenameMap.t
    type power = Power.t
    type monomial = Monomial.t
               
    let compare a b = 0 (* TODO Change? *)

    let make coefficient monomial = { coeff = coefficient; mon = monomial }
                                  
    let coeff scaled = scaled.coeff
                     
    let monomial scaled = scaled.mon
                        
    let degree scaled = Monomial.degree scaled.mon
                      
    let simplify scaled = { scaled with mon = Monomial.simplify scaled.mon }

    let to_string_simplified scaled =
      if scaled.coeff == Big_int.one then Monomial.to_string scaled.mon
      else if scaled.mon == Monomial.one then String.concat "" ["(" ; (Big_int.to_string scaled.coeff) ; ")"] 
      else String.concat "" ["(" ; (Big_int.to_string scaled.coeff) ; ")" ; "*" ; (Monomial.to_string scaled.mon)]
      
    let to_string scaled = to_string_simplified (simplify scaled)
                         
    let of_string str = raise (Failure "Not implemented") (* TODO Use ocamlyacc here *)

    let to_z3_simplified ctx scaled =
      Z3.Arithmetic.mk_mul ctx [(Z3.Arithmetic.Integer.mk_numeral_s ctx (Big_int.to_string scaled.coeff)) ; (Monomial.to_z3 ctx scaled.mon)]
      
    let to_z3 ctx scaled =
      to_z3_simplified ctx (simplify scaled)
      
    let (==) scaled1 scaled2 =
      (scaled1.coeff == scaled2.coeff) && (Monomial.(==) scaled1.mon scaled2.mon)
      
    let rename varmapping scaled = { scaled with mon = Monomial.rename varmapping scaled.mon }
                                 
    let eval scaled valuation =
      scaled.coeff * (Monomial.eval scaled.mon valuation)
      
    let mult_with_const const scaled = { scaled with coeff = scaled.coeff * const }
                                     
    let mult scaled1 scaled2 =
      {
        coeff = scaled1.coeff * scaled2.coeff;
        mon = Monomial.mult scaled1.mon scaled2.mon
      }

    let one =
      {
        coeff = Big_int.one;
        mon = Monomial.one
      }
      
    let lift mon =
      {
        coeff = Big_int.one;
        mon = mon
      }

    let vars scaled = Monomial.vars scaled.mon

  end

module StringScaledMonomial = MakeScaledMonomial(StringID)
