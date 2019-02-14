open Batteries
open ProgramTypes
open Sys
open Unix
open Parameter
open ExactProgramTypes
open BoundsInst
(*let description = "Testing for exactRuntime"

let command = "exact"

type params = {
  in_file : string; [@aka ["i"]]
  (** path to input file *)
  logging : bool; [@default false] [@aka ["l"]]
  (** enable logging *)
} [@@deriving cmdliner, show]*)

let read_process_lines command =
  let lines = ref [] in
  let in_channel = Unix.open_process_in command in
  begin
    try
      while true do
        lines := input_line in_channel :: !lines
      done;
    with 
      | BatInnerIO.Input_closed -> ()
      | End_of_file -> ()
  end;
  List.rev !lines

let get_koat_path (command: String.t) = 
  let which_output = read_process_lines ("which " ^ command) |> String.concat "" in
  (* Returns nothing when it is called as the executable at the current working directory *)
  if String.is_empty which_output then
    Filename.current_dir_name
  (* Else a path to the koatP executable is given whether it is the 
  relative path or the total path. Though it is handled the same way
  I have split it up for now in case it has to be changed later *)
  else if Char.equal which_output.[0] '/' then
    Filename.dirname which_output
  else Filename.dirname which_output

type result = {
  string_res: string option;
  warning: string option;
  error: string option;
  time: string option;
  evaluation: string option;
  bound: ExactBound.t option;
}

let rec get_from_list_ = function
  | (search, key :: value :: tail) -> if String.equal search key then Some value else get_from_list_ (search, tail)
  | (_, x :: []) -> None
  | (_, []) -> None

let get_from_list search list =
  get_from_list_ (search, list)

let result_from_list list = {
    string_res = get_from_list "STRING" list;
    warning = get_from_list "WARNING" list;
    error = get_from_list "ERROR" list;
    time = list |> get_from_list "TIME" ;
    evaluation = list |> get_from_list "EVALUATION" ;
    bound = list |> get_from_list "TREE" |> Option.map ExactReader.from_tree ;
  }

let bound_from_result res = 
  res.bound


let result_to_string_list (res:result) =
  let string_res = 
    (res.string_res |> Option.map (fun str -> ("RESULT: " ^ str) |> List.make 1)) |? []
  in
  let warning = 
    (res.warning |> Option.map (fun warn -> ("WARNING: " ^ warn) |> List.make 1)) |? []
  in
  let error = 
    (res.error |> Option.map (fun err -> ("ERROR: " ^ err) |> List.make 1)) |? []
  in
  let evaluation = 
    (res.evaluation |> Option.map (fun eval -> ("EVALUATION: " ^ eval) |> List.make 1)) |? []
  in
  let time =
    (res.time |> Option.map (fun time -> ("TIME: " ^ time) |> List.make 1)) |? []
  in
  string_res @ warning @ error @ evaluation @ time

let tap_option (f: 'a -> unit) (a: 'a option) : 'a option =
  Option.may f a;
  a

let run (params: params) =
  (* let logs = List.map (fun log -> (log, params.log_level)) params.logs in
    Logging.use_loggers logs; *)
  let logger = Logging.(get ExactRuntime) in
  
  let input = Option.default_delayed read_line params.input in
  let input_filename = input |> Fpath.v |> Fpath.normalize |> Fpath.to_string in
  let output_dir = params.output_dir in
  let write_to_file output =
    let out_name = (input |> Fpath.v |> Fpath.rem_ext |> Fpath.filename) ^ ".result" in
    Option.map (fun out_dir -> File.write_lines (out_dir ^ out_name) (List.enum output)) output_dir
    |> ignore
  in

  let print_output output =
    output |> String.concat "\n" |> print_string; print_string "\n"
  in

  let execute () =
    let sage_path = get_koat_path Sys.argv.(0) ^ "/../exactruntime/exact_runtime_from_koat.sage" in
    input_filename
    |> Readers.read_exact_file
    |> (fun ep -> if ExactProgram.is_valid ~logger:logger ep then Some ep else None)
    |> Option.map (fun ep -> 
                      ep
                      |> ExactProgram.to_sage
                      |> fun args -> "sage " ^ sage_path ^ " " ^ args
                      |> read_process_lines
                      |> result_from_list
                  )
    |> tap_option (fun res ->
                        res
                        |> result_to_string_list
                        |> tap print_output
                        |> tap write_to_file
                        |> ignore
                      )
    |> Option.map bound_from_result
    |> Option.map Option.get
    |> tap_option (fun res ->
                        res
                        |> ExactBound.get_lower_bound
                        |> RealBound.to_string
                        |> fun str -> "LOWER: " ^ str ^ "\n"
                        |> print_string
                  )
  in
  Logger.with_log logger Logger.DEBUG 
                  (fun () -> "Calculating exact runtime.", [])
                  ~result:(fun res ->
                    res |? ExactBound.infinity
                    |> ExactBound.to_string
                  )
                  execute
  |> ignore
