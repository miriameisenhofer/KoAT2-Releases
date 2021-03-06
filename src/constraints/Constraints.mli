open Batteries
open Atoms

(** Provides default implementations of a constraint. A constraint is a conjunction of atoms *)

(** Constructs a default constraint using a list of atoms each comparing two polynomials *)
module ConstraintOver(A : ConstraintTypes.Atom) : ConstraintTypes.Constraint
       with type polynomial = A.polynomial
        and type value = A.value
        and type atom = A.t
        and type t = A.t list

module Constraint :
sig
  include module type of ConstraintOver(Atom)

  (** Drops all nonlinear atoms from the constraints.
      Example: (a > 0 && b^2 < 2) gets transformed to (a > 0) *)
  val drop_nonlinear : t -> t

  (** The result of the following drop methods is not equivalent to the input constraint.
      But each satisfying valuation of the input constraint is still a model of the new constraint. *)

  (** Returns the row of all coefficients of a variable in a constraint...used for farkas quantor elimination*)
  val get_coefficient_vector : Var.t -> t -> value list

  val get_matrix : Var.t list -> t -> value list list

  (** Returns the row of all coefficients of a variable in a constraint...used for farkas quantor elimination*)
  val get_constant_vector : t -> value list

  val dualise : Var.t list -> A.P.t list list -> A.P.t list -> t

  val max_of_occurring_constants : t -> OurInt.t

  (* Add operations specific to polynomial constraints here if needed *)
end

module ParameterConstraint :
sig
  include module type of ConstraintOver(ParameterAtom)

  val of_constraint : Constraint.t -> t

  (** Returns the row of all coefficients of a variable in a constraint...used for farkas quantor elimination*)
  val get_coefficient_vector : Var.t -> t -> value list

  val get_matrix : Var.t list -> t -> value list list

  (** Returns the row of all coefficients of a variable in a constraint...used for farkas quantor elimination*)
  val get_constant_vector : t -> value list

  val farkas_transform : Constraint.t -> Atoms.ParameterAtom.t -> Constraint.t

  (* Add operations specific to parameter constraints here if needed *)
end

module RealConstraint :
sig
  include module type of ConstraintOver(RealAtom)

  val max_of_occurring_constants : t -> OurFloat.t

  (* Add operations specific to polynomial constraints here if needed *)
  val of_intconstraint : Constraint.t -> t
end

module RealParameterConstraint :
sig
  include module type of ConstraintOver(RealParameterAtom)

  val of_realconstraint : RealConstraint.t -> t
  val of_intconstraint  :     Constraint.t -> t

  val farkas_transform : t -> Atoms.RealParameterAtom.t -> RealConstraint.t

  (* Add operations specific to parameter constraints here if needed *)
end

module BoundConstraint :
sig
  include module type of ConstraintOver(BoundAtom)

  (* Add operations specific to parameter constraints here if needed *)
end
