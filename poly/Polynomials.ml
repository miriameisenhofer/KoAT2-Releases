open Batteries
   
module MakePolynomial(Var : PolyTypes.ID)(Value : Number.Numeric) =
  struct
    module Power = Powers.MakePower(Var)(Value)
    module Monomial = Monomials.MakeMonomial(Var)(Value)
    module ScaledMonomial = ScaledMonomials.MakeScaledMonomial(Var)(Value)
    module Valuation_ = Valuation.MakeValuation(Var)(Value)
    module RenameMap_ = RenameMap.MakeRenameMap(Var)
                          
    type t = ScaledMonomial.t list 
    type power = Power.t
    type monomial = Monomial.t
    type scaled_monomial = ScaledMonomial.t
                        
    module Var = Var
    module Value = Value

    let make scaleds = scaleds

    let lift scaled = [scaled]

    let degree poly =
      List.max (List.map (ScaledMonomial.degree) poly )
      
    (* Returns the coefficient of a monomial *)
    let coeff mon poly =
         poly
      |> List.filter (fun scaled -> Monomial.(==) (ScaledMonomial.monomial scaled) mon)
      |> List.map ScaledMonomial.coeff
      |> List.fold_left Value.add Value.zero

    let delete_monomial mon poly =
      List.filter (fun x -> not (Monomial.(==) (ScaledMonomial.monomial x) mon)) poly

    let rec simplify_partial_simplified poly =
      match poly with 
      | [] -> []
      | scaled::tail ->
         let curr_monom = ScaledMonomial.monomial scaled in
         let curr_coeff = coeff curr_monom poly in
         if (Value.equal curr_coeff Value.zero) then (simplify_partial_simplified (delete_monomial curr_monom tail))
         else (ScaledMonomial.make curr_coeff curr_monom) :: (simplify_partial_simplified (delete_monomial curr_monom tail) )

    let simplify poly =
      simplify_partial_simplified (List.map (ScaledMonomial.simplify) poly)

    let to_string_simplified poly = 
      if (poly == []) then "0" 
      else 
        String.concat "+" (List.map ScaledMonomial.to_string poly)

    let to_string poly = to_string_simplified (simplify poly)

    let of_string poly = raise (Failure "of_string for Polynomial not yet implemented") (* TODO Use ocamlyacc *)

    let data = List.map ScaledMonomial.data

    let rec equal_simplified poly1 poly2 =
      List.length poly1 == List.length poly2 &&
        match poly1 with
        | [] -> true
        | scaled :: tail ->
           let curr_mon = ScaledMonomial.monomial scaled in
           let curr_coeff = ScaledMonomial.coeff scaled in
           Value.equal curr_coeff (coeff curr_mon poly2) &&
             equal_simplified tail (delete_monomial curr_mon poly2)

    (* Returns the monomials of a polynomial without the empty monomial *)
    let monomials poly =
         poly
      |> simplify
      |> List.map ScaledMonomial.monomial
      |> List.filter ((<>) Monomial.one)

    (* Returns a variable as a polynomial *)

    let from_scaled_monomial = lift

    let from_monomial mon = from_scaled_monomial (ScaledMonomial.lift mon)

    let from_power power = from_monomial (Monomial.lift power)
      
    let from_constant c = lift (ScaledMonomial.make c Monomial.one)

    let from_var var = from_power (Power.lift var)

    let from_var_string str = from_var (Var.of_string str)

    let from_constant_int c = from_constant (Value.of_int c)
                      
    (* Gets the constant *)
    let constant poly = coeff Monomial.one (simplify poly)

    (* Returns the variables of a polynomial *)          
    let vars poly =
         poly
      |> simplify
      |> monomials
      |> List.map Monomial.vars
      |> List.concat
      |> List.unique
      
    (* Checks whether a polynomial is a single variable *)
    let is_var poly =
         poly
      |> simplify
      |> monomials
      |> fun monomials -> List.length monomials == 1 &&
                            Monomial.is_univariate_linear (List.hd monomials) && (Value.equal (coeff (List.hd monomials) poly) Value.one)

    (* Checks wheather a polynomial is a single variable plus a constant*)
    let is_var_plus_constant poly =
         poly
      |> delete_monomial Monomial.one
      |> is_var

    (* Checks whether a polynomial is a sum of variables plus a constant *)
    let is_sum_of_vars_plus_constant poly =
         poly
      |> delete_monomial Monomial.one
      |> List.for_all (fun scaled -> Value.equal (ScaledMonomial.coeff scaled) Value.one &&
                                       Monomial.is_univariate_linear (ScaledMonomial.monomial scaled))

    (* Checks whether a polyomial is linear and contains just one active variable*)
    let is_univariate_linear poly = 
      degree poly == 1 && List.length (vars poly) == 1

    let is_const poly = degree poly <= 0

    let is_linear poly = (degree poly == 1)

    (*renames the variables occuring inside a polynomial*) 

    let rename varmapping poly =
      List.map (ScaledMonomial.rename varmapping) poly

    (*multiply a polynomial by a constant*)

    let mult_with_const const poly =
      List.map (ScaledMonomial.mult_with_const const) poly

    type outer_t = t
    module BaseMathImpl : (PolyTypes.BaseMath with type t = outer_t) =
      struct
        type t = outer_t
               
        let zero = []
                 
        let one = lift ScaledMonomial.one
                
        let neg poly =
          mult_with_const (Value.neg Value.one) poly
          
        let add poly1 poly2 =
          simplify (List.append poly1 poly2)
          
        let mul poly1 poly2 =
             List.cartesian_product poly1 poly2
          |> List.map (fun (a, b) -> ScaledMonomial.mul a b) 
           
        let pow poly d =
             poly
          |> Enum.repeat ~times:d
          |> Enum.fold mul one
      
      end
    include PolyTypes.MakeMath(BaseMathImpl)

    module BasePartialOrderImpl : (PolyTypes.BasePartialOrder with type t = outer_t) =
      struct
        type t = outer_t
               
        let (==) poly1 poly2 = 
          equal_simplified (simplify poly1) (simplify poly2)
          
        let (>) p1 p2 = match (p1, p2) with
          (* TODO Find some rules to compare polynomials *)
          | ([s1], [s2]) -> ScaledMonomial.(>) s1 s2
          | _ -> None
               
      end
    include PolyTypes.MakePartialOrder(BasePartialOrderImpl)

    let is_zero poly = simplify poly == zero

    let is_one poly = simplify poly == one
                     
    (*instantiates the variables in a polynomial with big ints*)

    let eval poly valuation =
         poly
      |> List.map (fun scaled -> ScaledMonomial.eval scaled valuation)
      |> List.fold_left Value.add Value.zero

    let replace poly poly_valuation =
      raise (Failure "Replace for Polynomial not yet implemented")
  end
