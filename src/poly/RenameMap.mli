open Batteries

(** A rename map is a function which maps from a finite set of variables to another finite set of variables *)

type t
type var = Var.t

val from : (var * var) list -> t

val of_enum: (var * var) Enum.t -> t

(** Creates a rename map from a two strings (vars) association list *)
val from_native : (string * string) list -> t

(** Creates a rename map where every variable keeps its name *)
val id : var list -> t

(** Returns the new name of the variable or a default value, if the rename map does not assign a new name to the variable *)
val find : var -> t -> default:var -> var

val enum: t -> (Var.t * Var.t) Enum.t

