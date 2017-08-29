open Batteries

(** Provides module types which represent a minimal subset of their complete counterparts in the modules contraints and poly.
    Those are the minimal methods needed to construct the types from a textual representation *)

module type Polynomial =
  sig
    type t
    module Var : PolyTypes.ID
    val value : int -> t
    val var : string -> t
    val to_string : t -> string
    include PolyTypes.BaseMath with type t := t
  end
  
module type Atom =
  sig
    type t
    module Polynomial_ : Polynomial
    val mk_gt : Polynomial_.t -> Polynomial_.t -> t
    val mk_ge : Polynomial_.t -> Polynomial_.t -> t
    val mk_lt : Polynomial_.t -> Polynomial_.t -> t
    val mk_le : Polynomial_.t -> Polynomial_.t -> t
    val to_string : t -> string
  end
  
module type Constraint =
  sig
    type t
    module Atom_ : Atom
    
    val to_string : t -> string
    val mk : Atom_.t list -> t
    val mk_eq : Atom_.Polynomial_.t -> Atom_.Polynomial_.t -> t
    val mk_gt : Atom_.Polynomial_.t -> Atom_.Polynomial_.t -> t
    val mk_ge : Atom_.Polynomial_.t -> Atom_.Polynomial_.t -> t
    val mk_lt : Atom_.Polynomial_.t -> Atom_.Polynomial_.t -> t
    val mk_le : Atom_.Polynomial_.t -> Atom_.Polynomial_.t -> t
    val all : t list -> t
    val is_true : t -> bool
  end
   
module type Location =
  sig
    type t
    val to_string : t -> string
    val of_string : string -> t       
  end
   
module type Transition =
  sig
    type t
    module Constraint_ : Constraint
    exception RecursionNotSupported
    val mk : name:string ->
             start:string ->
             targets:(string * (Constraint_.Atom_.Polynomial_.t list)) list ->
             patterns:Constraint_.Atom_.Polynomial_.Var.t list ->
             guard:Constraint_.t ->
             vars:Constraint_.Atom_.Polynomial_.Var.t list ->
             t
    val start : t -> string
    val target : t -> string
    val to_string : string -> string -> t -> string
  end

module type TransitionGraph =
  sig
    type t
    module Transition_ : Transition
    module Location_ : Location
    val from : Transition_.Constraint_.Atom_.Polynomial_.Var.t list
               -> Transition_.t list
               -> Location_.t
               -> t
    val to_string : t -> string
  end

