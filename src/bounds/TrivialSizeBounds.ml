open Batteries
open Program.Types

let logger = Logging.(get Size)

type kind = [ `Lower | `Upper ] [@@deriving show]
           
(** Returns the maximum of all incoming sizebounds applicated to the local sizebound.
    Corresponds to 'SizeBounds for trivial SCCs':
    S'(alpha) = max(S_l(alpha)(S(t',v_1),...,S(t',v_n)) for all t' in pre(t)) *)
let incoming_bound kind program get_sizebound lsb t =
  let execute () =
    let substitute_with_prevalues t' = LocalSizeBound.as_substituted_bound (fun kind v -> get_sizebound kind t' v) lsb in
    t
    |> Program.pre program
    |> Enum.map substitute_with_prevalues
    |> match kind with
        | `Lower -> Bound.minimum
        | `Upper -> Bound.maximum
  in Logger.with_log logger Logger.DEBUG
                     (fun () -> "compute highest incoming bound", ["lsb", (Bound.to_string % LocalSizeBound.as_bound) lsb;
                                                                   "transition", Transition.to_id_string t])
                  ~result:Bound.to_string
                  execute

(** Computes a bound for a trivial scc. That is an scc which consists only of one result variable without a loop to itself.
    Corresponds to 'SizeBounds for trivial SCCs'. *)
let compute kind program get_sizebound (t,v) =
  let execute () =
    let (lsb: LocalSizeBound.t) =
      LocalSizeBound.sizebound_local_rv kind (t, v)
      |> Option.get
    in
    if Program.is_initial program t then
      LocalSizeBound.as_bound lsb
    else incoming_bound kind program get_sizebound lsb t
  in Logger.with_log logger Logger.DEBUG
                     (fun () -> "compute trivial bound", ["kind", show_kind kind;
                                                          "rv", RV.to_id_string (t,v)])
                     ~result:Bound.to_string
                     execute

