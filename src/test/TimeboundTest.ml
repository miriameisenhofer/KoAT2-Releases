open Batteries
open OUnit2
open Helper
open Program.Types

(** Returns an overall timebound for the given program. *)
let find_timebound (program: Program.t): Bound.t =
  (program, Approximation.create program)
  |> Preprocessor.process_til_fixpoint Preprocessor.all
  |> (fun (program, appr) ->
    Bounds.find_bounds program appr
    |> fun appr -> Approximation.(Time.sum (time appr) program)
  )

(** Returns an overall costbound for the given program. *)
let find_costbound (program: Program.t): Bound.t =
  (program, Approximation.create program)
  |> Preprocessor.process_til_fixpoint Preprocessor.all
  |> (fun (program, appr) ->
    Bounds.find_bounds program appr
    |> fun appr -> Approximation.costbound appr program
  )

(** Shouldnt be here *)
module M = Map.Make(Var)
let from entries =
  let addEntry entry = match entry with
    | (key, value) -> M.add key value in
  List.fold_left (fun map keyadder -> keyadder map) M.empty (List.map addEntry entries)
  
let smaller_or_equal (vars: VarSet.t) b1 b2 =
  [-999999;0;999999]
  |> Enum.repeat ~times:(VarSet.cardinal vars)
  |> List.of_enum
  |> List.n_cartesian_product
  |> List.for_all (fun assignment ->
         let valuation =
           assignment
           |> List.map Bound.of_int
           |> List.combine (VarSet.to_list vars)
           |> from
           |> (fun map var -> M.find var map)
         in
         (
           Bound.(substitute_f valuation b1 <= substitute_f valuation b2) |? false
         )
       )
  
let tests = 
  "Overall costbound" >::: [
      
      ("Simple" >:::
         List.map (fun (minimal_sound_costbound_str, wanted_costbound_str, program_str) ->
             program_str >:: (fun _ ->
                     let program = Readers.read_program_simple program_str in
                     let minimal_sound_costbound = Readers.read_bound minimal_sound_costbound_str in
                     let wanted_costbound = Option.map Readers.read_bound wanted_costbound_str |? minimal_sound_costbound in
                     let costbound = find_costbound program in
                     assert_bool (String.concat " " [Bound.to_string costbound; "is not sound, since it is smaller than"; Bound.to_string minimal_sound_costbound])
                                 (smaller_or_equal (Program.vars program) minimal_sound_costbound costbound);
                     assert_bool (String.concat " " [Bound.to_string costbound; "is not as small as wanted, since it is greater than"; Bound.to_string wanted_costbound])
                                 (smaller_or_equal (Program.vars program) costbound wanted_costbound)))
                  [
                    (* Constant bound *)

                    ("1", None,
                     "a -> b(x)");

                    ("2", None,
                     "a -> b(x), b -> c(x)");

                    ("2", Some "4",
                     "a -> b(x), b -> c(x), b -> d(x)");

                    ("3", Some "5",
                     "a -> b(x), b -> c(x), b -> d(x), c -> d(x)");

                    ("11", None,
                     "a -> b(10), b -> b(x-1) :|: x>0");

                    ("6", None,
                     "a -> b(10), b -> b(x-2) :|: x>0");

                    (* Linear bound *)

                    ("max{0,x}+1", None,
                     "a -> b(x), b -> b(x-1) :|: x>0");

                    ("max{0,x+y}+1", None,
                     "a -> b(x,y), b -> b(x-1,y) :|: x+y>0");

                    ("max{0,x-y}+1", None,
                     "a -> b(x,y), b -> b(x-1,y) :|: x>y");

                    ("max{0,y}+1", None,
                     "a -> b(0,y), b -> b(x+1,y) :|: x<y");

                    ("max{0,x}+max{0,y}+2", None,
                     "a -> b(x,y), b -> b(x-1,y) :|: x>0, b -> c(x,y), c -> c(x,y-1) :|: y>0");

                    ("max{0,min{x,y}}+1", Some "max{0,y}+1",
                     "a -> b(x,y), b -> b(x-1,y-1) :|: x>0 && y>0");

                    ("max{0,x}+max{0,max{0,x}+y}+2", None,
                     "a -> b(x,y), b -> b(x-1,y+1) :|: x>0, b -> c(x,y) :|: x<=0, c -> c(x,y-1) :|: y>0");

                    (* Quadratic bound *)
                  ]
      );
      
    ]
