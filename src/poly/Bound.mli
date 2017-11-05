open Batteries
open Polynomials
   
(** A MinMaxPolynomial is a polynomial which allows the usage of min and max functions  *)

type t

include PolyTypes.Evaluable with type t := t with type value = OurInt.t
include PolyTypes.Math with type t := t
include PolyTypes.PartialOrder with type t := t

type polynomial = PolynomialOver(OurInt).t

(** Following methods are convenience methods for the creation of polynomials. *)

val of_poly : polynomial -> t              
val of_constant : value -> t
val of_int : int -> t
val to_int : t -> int
val of_var : Var.t -> t
val of_var_string : string -> t
  
val min : t -> t -> t
val max : t -> t -> t

(** Returns a bound representing the minimum of all the values.
    Raises an exception, if the enum is empty.
    Use the function infinity for those cases. *)
val minimum : t Enum.t -> t
(** Returns a bound representing the maximum of all the values.
    Raises an exception, if the enum is empty.
    Use the function minus_infinity for those cases. *)
val maximum : t Enum.t -> t
  
val infinity : t
val minus_infinity : t
val exp : value -> t -> t
val abs : t -> t
  
(** Stable structural equal, but not equality of the bounds *)
val equal : t -> t -> bool
(** Stable structural compare, but not an actual compare of the bounds *)
val compare : t -> t -> int
  
val to_string : t -> string

(** Following methods can be used to classify the type of the polynomial. *)

(** Substitutes every occurrence of the variable in the polynomial by the replacement polynomial.
        Ignores naming equalities. *)
val substitute : Var.t -> replacement:t -> t -> t

(** Substitutes every occurrence of the variables in the polynomial by the corresponding replacement polynomial.
        Leaves all variables unchanged which are not in the replacement map.  *)
val substitute_all : t Map.Make(Var).t -> t -> t

(** Substitutes every occurrence of the variables in the polynomial by the corresponding replacement polynomial. *)
val substitute_f : (Var.t -> t) -> t -> t
  
(** Replaces all arithmetical operations by new constructors. *)
val fold : const:(value -> 'b) ->
           var:(Var.t -> 'b) ->
           neg:('b -> 'b) ->               
           plus:('b -> 'b -> 'b) ->
           times:('b -> 'b -> 'b) ->
           pow:('b -> int -> 'b) ->
           exp:(value -> 'b -> 'b) ->
           min:('b -> 'b -> 'b) -> 
           max:('b -> 'b -> 'b) ->
           abs:('b -> 'b) -> 
           inf:'b ->
           t -> 'b 
