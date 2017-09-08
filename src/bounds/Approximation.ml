open Batteries

module Make(G : TransitionGraphTypes.TransitionGraph) =
  struct

    module TransitionGraph_ = G

    module Bound = MinMaxPolynomial.Make
                     (G.Transition_.Constraint_.Atom_.Polynomial_.Var)
                     (G.Transition_.Constraint_.Atom_.Polynomial_.Value)
       
    type bound = Bound.t

    type kind = Lower | Upper

    type t = {
        time: ((kind * G.Transition_.t), bound) Hashtbl.t;
        size: ((kind * G.Transition_.t * G.Transition_.Constraint_.Atom_.Polynomial_.Var.t), bound) Hashtbl.t;
      }


    let empty transitioncount varcount = {
        time = Hashtbl.create (2 * transitioncount);
        size = Hashtbl.create (2 * transitioncount * varcount);
      }

                                       
    (* Returns the default bound for a kind. *)
    let default_bound = function
      | Lower -> Bound.minus_infinity
      | Upper -> Bound.infinity

    (* Returns the operator to combine two bounds with the best result. *)
    let combine_bounds = function
      | Lower -> Bound.max
      | Upper -> Bound.min

               
    let timebound kind appr transition =
      Hashtbl.find_option appr.time (kind, transition)
      |? default_bound kind

    let timebound_graph kind appr graph =
      match kind with
      | Lower -> Bound.one
      | Upper -> G.Graph.fold_edges_e (fun (start, transition, target) -> Bound.add (timebound Upper appr transition)) (G.graph graph) Bound.zero

    let add_timebound kind bound transition appr =
      Hashtbl.modify (kind, transition) (combine_bounds kind bound) appr.time;
      appr
      

    let sizebound kind appr transition var =
      Hashtbl.find_option appr.size (kind, transition, var)
      |? default_bound kind      

    let sizebound_local kind appr transition var =
      raise (Failure "Not yet implemented")

    let add_sizebound kind bound transition var appr =
      Hashtbl.modify (kind, transition, var) (combine_bounds kind bound) appr.size;
      appr      

  end
                     