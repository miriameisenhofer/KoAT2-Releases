open Batteries
open OUnit2
open Formulas
open Constraints
open Atoms
open Polynomials
   
(* TODO REDUNDANT in LocalSizeBound
   There is no to_string for options in batteries,
   but there is a very efficient print function which is however a bit inconvenient to use. *)
let to_string_template_bound_option (option: LocalSizeBound.t Option.t): string =
  let output = IO.output_string () in
  Option.print (fun output template_bound -> IO.nwrite output (Bound.to_string (LocalSizeBound.as_bound (Some template_bound)))) output option;
  IO.close_out output

let to_string_option (to_string: 'a -> string) (option: 'a Option.t): string =
  let output = IO.output_string () in
  Option.print (fun output a -> IO.nwrite output (to_string a)) output option;
  IO.close_out output

let to_string_varset_enum (enum: VarSet.t Enum.t): string =
  let output = IO.output_string () in
  Enum.print (fun output varset -> IO.nwrite output (VarSet.to_string varset)) output enum;
  IO.close_out output
  
let assert_equal_bool = assert_equal ~printer:Bool.to_string ~cmp:Bool.equal

let assert_equal_string = assert_equal ~printer:identity ~cmp:String.equal

let assert_equal_int = assert_equal ~printer:string_of_int ~cmp:Int.equal

let assert_equal_varset_enum =
  assert_equal ~cmp:(Enum.equal VarSet.equal) ~printer:to_string_varset_enum

let assert_equal_value =
  assert_equal ~cmp:OurInt.(=~=) ~printer:OurInt.to_string

let assert_equal_varset =
  assert_equal ~cmp:VarSet.equal ~printer:VarSet.to_string
  
let assert_equal_poly =
  assert_equal ~cmp:Polynomial.(=~=) ~printer:Polynomial.to_string

let assert_equal_parameter_poly =
  assert_equal ~cmp:ParameterPolynomial.(=~=) ~printer:ParameterPolynomial.to_string

let assert_equal_bound =
  assert_equal ~cmp:Bound.(=~=) ~printer:Bound.to_string

let assert_equal_bound_option =
  assert_equal ~cmp:(Option.eq ~eq:Bound.(=~=)) ~printer:(to_string_option Bound.to_string)

let assert_equal_atom =
  assert_equal ~cmp:Atom.(=~=) ~printer:Atom.to_string

let assert_equal_constr =     
  assert_equal ~cmp:Constraint.(=~=) ~printer:Constraint.to_string

let assert_equal_template_bound_option =
  assert_equal ~cmp:(Option.eq ~eq:LocalSizeBound.equal) ~printer:to_string_template_bound_option

let assert_equal_classified_bound =
  assert_equal ~cmp:LocalSizeBound.equal ~printer:LocalSizeBound.to_string

let assert_equal_formula =
  assert_equal
    ~cmp:(fun f1 f2 -> SMT.Z3Solver.unsatisfiable Formula.Infix.(f1 && Formula.neg f2))
    ~printer:Formula.to_string

let assert_equal_program =     
  assert_equal ~cmp:Program.equal ~printer:Program.to_string
  
let assert_true = assert_bool ""
                
let assert_false b = assert_true (not b)

let assert_exception f =
  assert_true (Result.is_bad (Result.catch f ()))
