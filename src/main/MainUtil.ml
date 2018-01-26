open Batteries

let read_input ?(rename=false) simple program_str =
  if simple then
    program_str
    |> Readers.read_program_simple
    |> (if rename then Program.rename else identity)
    |> Option.some
  else
    try
      program_str
      |> Readers.read_file
      |> (if rename then Program.rename else identity)
      |> Option.some
    with TransitionLabel.RecursionNotSupported ->
      prerr_string "ERROR: The given program uses recursion. Recursion is not supported by the current version of koat. The program will exit now."; None

