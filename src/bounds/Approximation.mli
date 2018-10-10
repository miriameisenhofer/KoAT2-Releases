open Batteries
open BoundsInst
open ProgramTypes
   
module TransitionApproximation : 
  sig
    include module type of TransitionApproximationType.Make_TransitionApproximation(OurInt)(Polynomials.Polynomial)
                                                                                   (struct 
                                                                                     include Transition
                                                                                     let fold_transset = TransitionSet.fold
                                                                                    end)

  end

module GeneralTransitionApproximation : 
  sig
    include module type of TransitionApproximationType.Make_TransitionApproximation(OurFloat)(Polynomials.RealPolynomial)
                                                                                   (struct 
                                                                                     include GeneralTransition
                                                                                     let fold_transset fold_func tset start_val = 
                                                                                       GeneralTransitionSet.from_transitionset tset
                                                                                       |> fun gtset -> GeneralTransitionSet.fold fold_func gtset start_val
                                                                                     let compare_same = compare
                                                                                    end)

  end

module SizeApproximation : 
  sig
    include module type of SizeApproximationType.Make_SizeApproximation(OurInt)(Polynomials.Polynomial)
                                                                       (struct 
                                                                         include Transition
                                                                         let target_string = 
                                                                           Location.to_string % Transition.target
                                                                        end)
                                                                       (RVGTypes.Make_RV (Transition))
  end

module RV : sig include module type of RVGTypes.Make_RV(Transition) end

(** Provides default implementations of an approximation *)

type t 
   
(** Distinguish between lower and upper bounds *)
type kind = [ `Lower | `Upper ]

(** Returns an empty approximation that does not contain any non-trivial information.
    That means, that every upper bound is infinite and every lower bound is minus infinite.
    The first parameter should be the count of transitions in the program.
    The second parameter should be the count of program variables. *)
val empty : int -> int -> int -> t

val create : Program.t -> t

val time : t -> TransitionApproximation.t

val exptime : t -> GeneralTransitionApproximation.t

val size : t -> SizeApproximation.t

val cost : t -> TransitionApproximation.t
  
val to_string : Program.t -> t -> string

val equivalent : t -> t -> bool


(** Timebound related methods *)
  
(** Returns a timebound for the transition. *)
val timebound : t -> Transition.t -> Bound.t

(** Returns an expected timebound for the transition. *)
val exptimebound : t -> GeneralTransition.t -> RealBound.t

(** Returns a timebound for the transition id. *)
val timebound_id : t -> int -> Bound.t

(** Returns a timebound for the program. *)
val program_timebound : t -> Program.t -> Bound.t

(** Adds the information that the specified bound is a valid timebound for the given transition. 
    The resulting approximation is guaranteed to be at least as good as the old approximation. *)
val add_timebound : Bound.t -> Transition.t -> t -> t

(** Adds the information that the specified bound is a valid expected timebound for the given general transition. 
    The resulting approximation is guaranteed to be at least as good as the old approximation. *)
val add_exptimebound : RealBound.t -> GeneralTransition.t -> t -> t

val all_times_bounded : t -> Transition.t list -> bool
  
val is_time_bounded : t -> Transition.t -> bool

val is_exptime_bounded : t -> GeneralTransition.t -> bool

(** Costbound related methods *)

(** Returns a costbound for the transition. *)
val costbound : t -> Transition.t -> Bound.t

(** Returns a costbound for the program. *)
val program_costbound : t -> Program.t -> Bound.t

val add_costbound : Bound.t -> Transition.t -> t -> t

  
(** Sizebound related methods *)

(** Returns a sizebound of the specified kind for the var of the transition. 
        A sizebound is expressed in relation to the input variable values of the program. *)
val sizebound : kind -> t -> Transition.t -> Var.t -> Bound.t

(** Adds the information that the specified bound is a valid sizebound for the given variable of the transition. 
        The resulting approximation is guaranteed to be at least as good as the old approximation. *)
val add_sizebound : kind -> Bound.t -> Transition.t -> Var.t -> t -> t
  
val add_sizebounds : kind -> Bound.t -> RV.t list -> t -> t
