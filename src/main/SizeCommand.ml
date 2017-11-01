open Batteries

let description = "Run a size bound improvement step"

let command = "size"
   
type params = {

    program : string; [@pos 0] [@docv "FILE"]
    (** The file of the program which should be analyzed. *)

  } [@@deriving cmdliner, show]

let run (params: params) =
  Logger.init ["size", Logger.DEBUG] (Logger.make_dbg_formatter IO.stdout);
  let appr = Approximation.empty 10 3
  and program = Readers.read_file params.program in
  SizeBounds.improve program appr
  |> Approximation.to_string program
  |> print_string
