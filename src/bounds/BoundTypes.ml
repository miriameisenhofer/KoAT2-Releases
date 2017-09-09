open Batteries

(** Provides all module types related to bounds *)

(** An atom is a comparison between two polynomials *)
module type Approximation =
  sig
    module Program_ : ProgramTypes.Program

    module Bound : module type of MinMaxPolynomial.Make
                                    (Program_.Constraint_.Polynomial_.Var)
                                    (Program_.Constraint_.Polynomial_.Value)
         
    type t
         
    (** Distinguish between lower and upper bounds *)
    type kind = Lower | Upper

                      
    (** Returns an empty approximation that does not contain any non-trivial information.
        That means, that every upper bound is infinite and every lower bound is minus infinite.
        The first parameter should be the count of transitions in the program.
        The second parameter should be the count of program variables. *)
    val empty : int -> int -> t

      
    (** Timebound related methods *)
                        
    (** Returns a timebound of the specified kind for the transition. *)
    val timebound : kind -> t -> Program_.Transition.t -> Bound.t

    (** Returns a timebound of the specified kind for the execution of the whole graph. *)
    val timebound_graph : kind -> t -> Program_.t -> Bound.t

    (** Adds the information that the specified bound is a valid timebound for the given transition. 
        The resulting approximation is guaranteed to be at least as good as the old approximation. *)
    val add_timebound : kind -> Bound.t -> Program_.Transition.t -> t -> t
      

    (** Sizebound related methods *)

    (** Returns a sizebound of the specified kind for the var of the transition. 
        A sizebound is expressed in relation to the input variable values of the program. *)
    val sizebound : kind -> t -> Program_.Transition.t -> Program_.Constraint_.Polynomial_.Var.t -> Bound.t

    (** Returns a local sizebound of the specified kind for the var of the transition. 
        A local sizebound is expressed in relation to the values directly before executing the transition. *)
    val sizebound_local : kind -> t -> Program_.Transition.t -> Program_.Constraint_.Polynomial_.Var.t -> Bound.t

    (** Adds the information that the specified bound is a valid sizebound for the given variable of the transition. 
        The resulting approximation is guaranteed to be at least as good as the old approximation. *)
    val add_sizebound : kind -> Bound.t -> Program_.Transition.t -> Program_.Constraint_.Polynomial_.Var.t -> t -> t

  end

module type RankingFunction =
  sig
    module Program_ : ProgramTypes.Program
    module Polynomial_ : PolyTypes.Polynomial

    type t

    (** Returns a non-empty list of all transitions which are strictly decreasing and at the same time bounded with one.
        Corresponds to T_> . *)
    val strictly_decreasing : t -> Program_.Transition.t list

    (** Returns a non-empty list of all transitions which are non increasing.
        This list also contains all transitions that are strictly decreasing. *)
    val non_increasing : t -> Program_.Transition.t list

    (** Finds a suitable ranking function which decreases at least one transition and does not increase any transition. *)
    val find : Program_.t -> t

    (** Transforms the ranking function to a monotonic function. *)
    val monotonize : t -> t
  end
  
module type TimeBounds =
  sig
    module Approximation_ : Approximation

    (** Performs a single improvement step to find better timebounds for the approximation and updates the approximation. *)
    val improve : Approximation_.Program_.t -> Approximation_.t -> Approximation_.t
  end
  
module type SizeBounds =
  sig
    module Approximation_ : Approximation

    (** Performs a single improvement step to find better sizebounds for the approximation and updates the approximation. *)
    val improve : Approximation_.Program_.t -> Approximation_.t -> Approximation_.t
  end
