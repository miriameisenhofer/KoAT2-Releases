open Batteries
open BoundsInst
open ProgramTypes
   
type kind = [ `Lower | `Upper ] [@@deriving eq, ord, show]

let logger = Logging.(get Approximation) 

module TransitionApproximation = TransitionApproximationType.Make_BoundOver(OurInt)(Polynomials.Polynomial)
                                   (struct 
                                     include Transition
                                     let fold_transset = TransitionSet.fold
                                    end)

module GeneralTransitionApproximation = TransitionApproximationType.Make_BoundOver(OurFloat)(Polynomials.RealPolynomial)
                                        (struct 
                                          include GeneralTransition
                                          let fold_transset fold_func tset start_val = 
                                            GeneralTransitionSet.from_transitionset tset
                                            |> fun gtset -> GeneralTransitionSet.fold fold_func gtset start_val
                                          let compare_same = compare
                                         end)

type t = {
    time: TransitionApproximation.t;
    exptime: GeneralTransitionApproximation.t;
    size: SizeApproximation.t;
    cost: TransitionApproximation.t;
  }

let equivalent appr1 appr2 =
  TransitionApproximation.equivalent appr1.time appr2.time
  && SizeApproximation.equivalent appr1.size appr2.size
  
let empty transitioncount varcount gtcount = {
    time = TransitionApproximation.empty "time" transitioncount;
    exptime = GeneralTransitionApproximation.empty "exptime" gtcount;
    size = SizeApproximation.empty (2 * transitioncount * varcount);
    cost = TransitionApproximation.empty "cost" transitioncount;
  }

let create program =
  empty (TransitionGraph.nb_edges (Program.graph program))
        (VarSet.cardinal (Program.vars program))
        (Program.transitions program |> GeneralTransitionSet.from_transitionset |> GeneralTransitionSet.cardinal)

let time appr = appr.time

let size appr = appr.size

let cost appr = appr.cost


(** Sizebound related methods *)

let sizebound kind =
  SizeApproximation.get kind % size

let add_sizebound kind bound transition var appr =
  { appr with size = SizeApproximation.add kind bound transition var appr.size }

let add_sizebounds kind bound scc appr =
  { appr with size = SizeApproximation.add_all kind bound scc appr.size }

(** Timebound related methods *)

let timebound =
  TransitionApproximation.get % time

let timebound_id =
  TransitionApproximation.get_id % time

let program_timebound =
  TransitionApproximation.sum % time

let add_timebound bound transition appr =
  let label = Transition.label transition in
  let temp_vars = VarSet.diff (TransitionLabel.vars label) (TransitionLabel.input_vars label) in
  let temp_bound = fun kind var -> if (VarSet.mem var temp_vars) then sizebound kind appr transition var else Bound.of_var var in
  let replaced_bound = Bound.appr_substitution `Upper ~lower:(temp_bound `Lower) ~higher:(temp_bound `Upper) bound in
  { appr with time = TransitionApproximation.add replaced_bound transition appr.time }

let all_times_bounded =
  TransitionApproximation.all_bounded % time

let is_time_bounded appr =
  not % Bound.is_infinity % timebound appr

(** Costbound related methods *)

let costbound =
  TransitionApproximation.get % cost

let program_costbound =
  TransitionApproximation.sum % cost

let add_costbound bound transition appr =
  { appr with cost = TransitionApproximation.add bound transition appr.cost }  
  
let to_string program appr =
  let overall_timebound = program_timebound appr program in 
  let output = IO.output_string () in
    if (not (Bound.is_infinity overall_timebound)) then
      IO.nwrite output ("YES( ?, " ^ Bound.to_string (overall_timebound) ^ ")\n\n")
    else
      IO.nwrite output "MAYBE\n\n";
    IO.nwrite output "Initial Complexity Problem:\n";
    IO.nwrite output (Program.to_string program^"\n");
    IO.nwrite output "Timebounds: \n";
    IO.nwrite output ("  Overall timebound: " ^ Bound.to_string (overall_timebound) ^ "\n");
    appr.time |> TransitionApproximation.to_string (Program.transitions program |> TransitionSet.to_list) |> IO.nwrite output;
    IO.nwrite output "\nCostbounds:\n";
    IO.nwrite output ("  Overall costbound: " ^ Bound.to_string (program_costbound appr program) ^ "\n");
    appr.cost |> TransitionApproximation.to_string (Program.transitions program |> TransitionSet.to_list) |> IO.nwrite output;
    IO.nwrite output "\nSizebounds:\n";
    appr.size |> SizeApproximation.to_string |> IO.nwrite output;
    IO.close_out output
