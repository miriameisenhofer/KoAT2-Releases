open Batteries
open ProgramTypes
open Sys
open Unix
let description = "Testing for exactRuntime"

let command = "exact"

type params = {
  in_file : string; [@aka ["i"]]
  (** path to input file *)
  logging : bool; [@default false] [@aka ["l"]]
  (** enable logging *)
} [@@deriving cmdliner, show]

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

let run (params: params) =
  if(params.logging) then
    Logging.(use_loggers [ExactRuntime, Logger.DEBUG])
  else
    Logging.(use_loggers []);
  let logger = Logging.(get ExactRuntime) in
  let execute () =
    (* No idea if this actaully works, may need adjustment in the future *)
    let sage_path = 
    get_koat_path Sys.argv.(0)
    |> fun koat_path -> koat_path ^ "/../exact_runtime/exact_runtime_from_file.sage"
    in
    params.in_file
    |> fun input -> "sage " ^ sage_path ^ " " ^ input
    |> read_process_lines
    (* Printed here for output reasons only *)
    |> tap(fun output -> output |> String.concat "\n" |> print_string; print_string "\n")
  in 
  Logger.with_log logger Logger.DEBUG 
                  (fun () -> "exact runtime", [])
                  ~result:(fun bound ->
                    String.concat "; " bound
                  )
                  execute
  |> ignore
