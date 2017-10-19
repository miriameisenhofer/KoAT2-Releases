open Batteries

module Location =
  struct
    type t = {
        name : string;
        (*initial : bool;*)
        (* TODO Possible optimization: invariant : PolynomialConstraints.t*)
      } [@@deriving eq, ord]
           
    (*Needed by ocamlgraph*)    
    let hash l = Hashtbl.hash l.name
               
    let to_string l = l.name
                    
    let of_string inp_name = { name = inp_name }
                       
  end

module TransitionGraph = Graph.Persistent.Digraph.ConcreteBidirectionalLabeled(Location)(TransitionLabel)

module Transition = struct
  include TransitionGraph.E
  let to_string (l,t,l') = Location.to_string l ^ "->" ^ Location.to_string l' ^ ", " ^ TransitionLabel.to_string t
  let equal (l1,t1,l'1) (l2,t2,l'2) =
       Location.equal l1 l2
    && TransitionLabel.equal t1 t2
    && Location.equal l'1 l'2
end

module RV =
  struct
    type t = Transition.t * Var.t [@@deriving eq, ord]
    let hash v = raise (Failure "Not yet implemented")
    let transition (t,v) = t
    let variable (t,v) = v
    let to_string ((l,t,l'),v) = Bound.to_string (LocalSizeBound.(as_bound (sizebound_local `Upper t v))) ^ " >= " ^
                                   "|" ^ Location.to_string l ^ " -> " ^ Location.to_string l' ^ "," ^ Var.to_string v ^ "|"
                                   ^ " >= " ^ Bound.to_string (LocalSizeBound.(as_bound (sizebound_local `Lower t v)))
  end
module RVG =
  struct
    include Graph.Persistent.Digraph.ConcreteBidirectional(RV)

    type scc = RV.t list

    let pre rvg rv =
      pred rvg rv
      |> List.enum

    (* TODO Optimizable *)
    let entry_points rvg scc =
      scc
      |> List.enum
      |> Enum.map (pre rvg)
      |> Enum.flatten
      |> Enum.uniq_by RV.equal
      |> Enum.filter (fun rv -> List.mem_cmp RV.compare rv scc)

    let transitions scc =
      scc
      |> List.enum
      |> Enum.map RV.transition
      |> Enum.uniq_by Transition.equal
  end  
   
module TransitionSet = Set.Make(Transition)
module CartesianSet = Set.Make2(Transition)(Var)

type transition_set = Set.Make(Transition).t

type t = {
    graph: TransitionGraph.t;
    vars: Var.t list;
    start: Location.t;
  }
       
let add_vertices graph vertices =
  vertices
  |> List.map (fun vertex -> fun gr -> TransitionGraph.add_vertex gr vertex)
  |> List.fold_left (fun gr adder -> adder gr) graph
  
let add_edges graph edges =
  edges
  |> List.map (fun edge -> fun gr -> TransitionGraph.add_edge_e gr edge)
  |> List.fold_left (fun gr adder -> adder gr) graph
  
let mk vertices edges =
  add_edges (add_vertices TransitionGraph.empty vertices) edges

let from vars transitions start =
  let edges = List.map (fun t -> (Location.of_string (TransitionLabel.start t),
                                  t,
                                  Location.of_string (TransitionLabel.target t)))
                       transitions in
  let vertices = List.unique (List.append
                                (List.map (fun (start, _, _) -> start) edges)
                                (List.map (fun (_, _, target) -> target) edges)) in
  {
    graph = mk vertices edges;
    vars = vars;
    start = start;
  }

let vars program =
  VarSet.of_list program.vars
  
let start program = program.start
  
let add_vertices_to_rvg vertices rvg =
  vertices
  |> List.map (flip RVG.add_vertex)
  |> List.fold_left (fun rvg adder -> adder rvg) rvg

let graph g = g.graph
            
let pre program (l,t,l') =
  TransitionSet.of_list (TransitionGraph.pred_e (graph program) l)

let rvg program =
  let add_transition (post_transition: Transition.t) (rvg: RVG.t): RVG.t =
    let rvg_with_vertices: RVG.t = add_vertices_to_rvg (List.map (fun var -> (post_transition,var)) program.vars) rvg in
    let pre_nodes (post_transition: Transition.t) (post_var: Var.t) =
      LocalSizeBound.sizebound_local `Upper (Transition.label post_transition) post_var
      |> LocalSizeBound.as_bound
      |> Bound.vars
      |> CartesianSet.cartesian_product (pre program post_transition)
      |> CartesianSet.Product.to_list
      |> List.map (fun (pre_transition,pre_var) -> (pre_transition,pre_var,post_var))
      |> Set.of_list
    in
    vars program
    |> VarSet.map_to_set (pre_nodes post_transition)
    |> (fun set -> Set.fold Set.union set Set.empty)
    |> (fun set -> Set.fold (fun (pre_transition,pre_var,post_var) rvg -> RVG.add_edge rvg (pre_transition,pre_var) (post_transition,post_var)) set rvg_with_vertices)
  in
  TransitionGraph.fold_edges_e add_transition program.graph RVG.empty
  
let print_graph out_dir name graph output_graph =
  (* Create output directory if not existing *)
  ignore (Sys.command ("mkdir -p " ^ out_dir));
  (* Write a graphviz dot file *)
  output_graph (Pervasives.open_out_bin (out_dir ^ "/" ^ name ^ ".dot")) graph;
  (* Generate a png from the dot file with an external call to graphviz *)
  ignore (Sys.command ("dot -T png -o " ^ (out_dir ^ "/" ^ name ^ ".png ") ^ (out_dir ^ "/" ^ name ^ ".dot")))
  
let print_system ~outdir ~file program =
  (* Definition of some graphviz options how it should be layout *)
  let module Dot = Graph.Graphviz.Dot(struct
                                       include TransitionGraph
                                       let edge_attributes (a, e, b) = [`Label (TransitionLabel.to_string e); `Color 4711]
                                       let default_edge_attributes _ = []
                                       let get_subgraph _ = None
                                       let vertex_attributes _ = [`Shape `Box]
                                       let vertex_name v = Location.to_string v
                                       let default_vertex_attributes _ = []
                                       let graph_attributes _ = []
                                     end) in
  print_graph outdir (file ^ "_system") (graph program) Dot.output_graph

let print_rvg ~outdir ~file program =
  (* Definition of some graphviz options how it should be layout *)
  let module Dot = Graph.Graphviz.Dot(struct
                                       include RVG
                                       let edge_attributes _ = [`Label ""; `Color 4711]
                                       let default_edge_attributes _ = []
                                       let get_subgraph _ = None
                                       let vertex_attributes _ = [`Shape `Box]
                                       let vertex_name v = "\"" ^ RV.to_string v ^ "\""
                                       let default_vertex_attributes _ = []
                                       let graph_attributes _ = []
                                     end) in
  print_graph outdir (file ^ "_rvg") (rvg program) Dot.output_graph

let is_initial program trans =
  Location.(program.start == (Transition.src trans))

let to_string graph =
  "TODO"
