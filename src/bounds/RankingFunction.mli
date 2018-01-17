open Batteries
open Constraints
open Atoms
open Polynomials
open Program.Types
   
(** Provides default implementations of RankingFunctions *)

type t

type measure = [ `Cost | `Time ] [@@deriving show]

(** Returns the ranking polynomial for the specific location. *)
val rank : t -> Location.t -> Polynomial.t

(** Returns a non-empty list of all transitions which are strictly decreasing and at the same time bounded with one.
    Corresponds to T_> . *)
val decreasing : t -> Transition.t
  
(** Returns a list of all transitions for which the prf is defined.
    Corresponds to T'. *)
val transitions : t -> Transition.t list

(** Finds a suitable ranking function for the given transitions T'. *)
val find : measure -> Program.t -> Transition.t -> t list

(** Converts a ranking function into a string*)
val to_string : t -> string

(** Resets all cached data.
    Useful for testing in the same OCaml instance. *)
val reset : unit -> unit
