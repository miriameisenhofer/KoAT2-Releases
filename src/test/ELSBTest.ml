open Batteries
open ProgramTypes
open Formulas
open BoundsInst
open OUnit2
open TestHelper

type concave_convex = Convex | Concave | None [@@deriving show]

let tests =
  let varx = RealBound.of_var @@ Var.of_string "X" in
  let vary = RealBound.of_var @@ Var.of_string "Y" in
  "ELSB" >::: [
    "elsb" >::: List.map
      (fun (gt,v,l,lower_bound, lower_bound_red, program_string) ->
        (Int.to_string gt) >::
          (fun _ ->
            let cache = CacheManager.new_cache () in
            let elsb_cache = CacheManager.elsb_cache cache in
            let prog = Readers.read_program (CacheManager.trans_id_counter cache) program_string in
            let gt_id_offset =
              Program.generalized_transitions prog
              |> GeneralTransitionSet.to_list
              |> List.map GeneralTransition.id
              |> List.sort compare
              |> List.hd
            in
            let gt =
              Program.generalized_transitions prog
              |> GeneralTransitionSet.filter ((=) (gt + gt_id_offset) % GeneralTransition.id)
              |> GeneralTransitionSet.any
            in
            let var = Var.of_string v in
            let loc =
                Program.graph prog |> TransitionGraph.locations
                |> LocationSet.filter ((=) l % Location.to_string) |> LocationSet.any
            in
            let rv = ((gt,loc),var) in
            let elsb     = ExpLocalSizeBound.(elsb         @@ compute_elsb elsb_cache prog rv) in
            let elsb_red = ExpLocalSizeBound.(reduced_elsb @@ compute_elsb elsb_cache prog rv) in
            let error_string =
              "elsb_mismatch elsb: " ^ (RealBound.show ~complexity:false elsb)
              ^ " expected " ^ (RealBound.show ~complexity:false lower_bound)
              ^ " in program " ^ (Program.to_string ~show_gtcost:true prog)
            in
            let error_string_red =
              "elsb_mismatch reduced_elsb: " ^ (RealBound.show ~complexity:false elsb_red)
              ^ " expected " ^ (RealBound.show ~complexity:false lower_bound_red)
              ^ " in program " ^ (Program.to_string ~show_gtcost:true prog)
            in
            assert_bool error_string (bounds_pos_vars lower_bound elsb);
            assert_bool error_string_red (bounds_pos_vars lower_bound_red elsb_red)
          )
      )
      [
        (0, "X", "g", RealBound.zero, RealBound.zero,
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> 0.5:g(X) :+: 0.5:g(X)      \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.zero, RealBound.zero,
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> 0.5:g(X) :+: 0.5:h(X)      \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.zero, RealBound.zero,
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X Y)                            \n"
        ^ "(RULES                               \n"
        ^ "  f(X,Y) -> g(X,2*Y)                 \n"
        ^ ")                                    \n"
        );

        (0, "Y", "g", RealBound.(abs @@ vary), RealBound.(abs @@ vary),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X Y)                            \n"
        ^ "(RULES                               \n"
        ^ "  f(X,Y) -> g(X,2*Y)                 \n"
        ^ ")                                    \n"
        );

        (0, "Y", "g", RealBound.(abs @@ vary), RealBound.(abs @@ vary),
          "(GOAL EXPECTEDCOMPLEXITY)                  \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))            \n"
        ^ "(VAR X Y)                                  \n"
        ^ "(RULES                                     \n"
        ^ "  f(X,Y) -> 0.5:g(X,2*Y) :+: 0.5:g(X,2*Y)  \n"
        ^ ")                                          \n"
        );

        (0, "Y", "g", RealBound.(of_constant (OurFloat.of_float 0.5) * abs vary), RealBound.(abs @@ vary),
          "(GOAL EXPECTEDCOMPLEXITY)                  \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))            \n"
        ^ "(VAR X Y)                                  \n"
        ^ "(RULES                                     \n"
        ^ "  f(X,Y) -> 0.5:g(X,2*Y)  :+: 0.5:h(X,2*Y) \n"
        ^ ")                                          \n"
        );

        (0, "Y", "g", RealBound.(abs @@ vary - (of_constant @@ OurFloat.of_int 5) * varx), RealBound.(abs @@ vary - (of_constant @@ OurFloat.of_int 5) * varx),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X Y)                            \n"
        ^ "(RULES                               \n"
        ^ "  f(X,Y) -> g(X,2*Y - 5*X)           \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.infinity, RealBound.infinity,
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(X+Z)                     \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_int 5)), RealBound.(of_constant (OurFloat.of_int 5)),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(X+Z) :|: Z=5             \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_int 10)), RealBound.(of_constant (OurFloat.of_int 10)),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(X+2*Z) :|: Z=5           \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_int 25)), RealBound.(of_constant (OurFloat.of_int 25)),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(X+Z*Z) :|: Z=5           \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_int 5)), RealBound.(of_constant (OurFloat.of_int 5)),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(X+Z) :|: Z<=5 && Z>=0    \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(abs @@ varx + of_constant (OurFloat.of_int 5)), RealBound.(abs @@ varx + of_constant (OurFloat.of_int 5)),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> g(Z) :|: Z<=5 && Z>=0      \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_int 50)), RealBound.(of_constant (OurFloat.of_int 50)),
          "(GOAL EXPECTEDCOMPLEXITY)                   \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))             \n"
        ^ "(VAR X)                                     \n"
        ^ "(RULES                                      \n"
        ^ "  f(X) -> g(X+Z*Y) :|: Z<=5 && Z>=0 && Y=10 \n"
        ^ ")                                           \n"
        );

        (0, "X", "g", RealBound.(of_constant @@ OurFloat.of_int 100), RealBound.(of_constant @@ OurFloat.of_int 100),
          "(GOAL EXPECTEDCOMPLEXITY)                     \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))               \n"
        ^ "(VAR X)                                       \n"
        ^ "(RULES                                        \n"
        ^ "  f(X) -> g(X+Z*Y) :|: Z<=5 && Z>=-10 && Y=10 \n"
        ^ ")                                             \n"
        );

        (0, "X", "g", RealBound.zero, RealBound.zero,
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> 0.5:g(X) :+: 0.5:h(3*X)    \n"
        ^ ")                                    \n"
        );

        (0, "X", "h", RealBound.(abs varx), RealBound.(abs varx),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> 0.5:g(X) :+: 0.5:h(3*X)    \n"
        ^ ")                                    \n"
        );

        (0, "X", "g", RealBound.(of_constant (OurFloat.of_float 1.5) * abs varx), RealBound.(of_constant (OurFloat.of_float 1.5) * abs varx),
          "(GOAL EXPECTEDCOMPLEXITY)            \n"
        ^ "(STARTTERM (FUNCTIONSYMBOLS f))      \n"
        ^ "(VAR X)                              \n"
        ^ "(RULES                               \n"
        ^ "  f(X) -> 0.5:g(0) :+: 0.5:g(3*X)    \n"
        ^ ")                                    \n"
        );
      ];
    "concave_convex_check" >::: List.map
      (
        fun (bstr,conc_conv) ->
          let cache = CacheManager.new_cache () in
          let elsb_cache = CacheManager.elsb_cache cache in
          let bound = Readers.read_bound bstr |> RealBound.of_intbound in
          let (valid,err_string) =
            match conc_conv with
            | Concave ->
              (ExpLocalSizeBound.bound_is_concave elsb_cache bound, "Bound " ^ bstr ^ " is not concave as expected!")
            | Convex ->
              (ExpLocalSizeBound.bound_is_convex elsb_cache bound, "Bound " ^ bstr ^ " is not convex as expected!")
            | None    ->
              match (ExpLocalSizeBound.bound_is_concave elsb_cache bound, ExpLocalSizeBound.bound_is_convex elsb_cache bound) with
              | (true,true)   -> (false, "Bound " ^ bstr ^ "is convex and concave!")
              | (true,false)  -> (false, "Bound " ^ bstr ^ "is concave!")
              | (false,true)  -> (false, "Bound " ^ bstr ^ "is convex!")
              | (false,false) -> (true, "")

          in
          "" >:: fun _ -> assert_bool err_string valid
      )
      [
        ("|A|", Concave);
        ("A", Concave);
        ("|A|", Convex);

        ("|A| + |B|", Concave);
        ("A + B", Concave);
        ("|A| + |B|", Convex);
        ("A + B", Convex);

        ("|A| + |B| + |C|", Concave);
        ("A + B + C", Concave);
        ("|A| + |B| + |C|", Convex);
        ("A + B + C", Convex);

        ("|A| + |B| + |C| + |D|", Concave);
        ("A + B + C + D", Concave);
        ("|A| + |B| + |C| + |D|", Convex);
        ("A + B + C + D", Convex);

        ("|A| * |B|", None);
        ("A * B", None);

        ("|A| * |B| * |C|", None);
        ("A * B * C", None);

        ("max {1,|A|}", Convex);
        ("max {1,A}", Convex);
        ("min {1,|A|}", Concave);
        ("min {1,A}", Concave);

        ("max {|A|,|B|}", Convex);
        ("max {A,B}", Convex);
        ("min {|A|,|B|}", Concave);
        ("min {A,B}", Concave);

        ("max {1,|A|,|B|}", Convex);
        ("max {1,A,B}", Convex);
        ("min {1,|A|,|B|}", Concave);
        ("min {1,A,B}", Concave);

        ("max {1,|A|,|B|, |A|*|B|}", None);
        ("max {1,A,B, A*B}", None);
        ("min {1,|A|,|B|, |A|*|B|}", None);
        ("min {1,A,B, A*B}", None);
      ]
  ]