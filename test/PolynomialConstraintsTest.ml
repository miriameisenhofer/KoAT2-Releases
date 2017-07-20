open Batteries
open ID
open Z3
open OUnit2
open PolyTypes
open ConstraintTypes
open PolynomialConstraintsAtoms

module PolynomialConstraintsTest (Var : ID) =
    struct
        module AST = PolynomialConstraintsAtomAST(Var)
        module PolynomialAST = PolynomialAST(Var)
        module Parser = PolynomialConstraintsAtomParser.Make(Var)
        module Lexer = PolynomialConstraintsAtomLexer.Make(Var)
        module Polynomial = Polynomials.MakePolynomial(Var)(Number.MakeNumeric(Big_int))
        module PolynomialConstraintsAtom = MakePolynomialConstraintsAtom(Var)(Number.MakeNumeric(Big_int))
        module Valuation = Valuation.MakeValuation(Var)(Number.MakeNumeric(Big_int))
    
    (* Unambigous transformation to string to make tests more readable *)
    let rec polynomial_to_string (ex : PolynomialAST.t) = match ex with
      | PolynomialAST.Constant c -> string_of_int c
      | PolynomialAST.Variable v -> Var.to_string v
      | PolynomialAST.Neg t -> String.concat "" ["("; "-"; polynomial_to_string t; ")"]
      | PolynomialAST.Plus (t1,t2) -> String.concat "" ["("; polynomial_to_string t1; "+"; polynomial_to_string t2; ")"]
      | PolynomialAST.Times (t1,t2) -> String.concat "" ["("; polynomial_to_string t1; "*"; polynomial_to_string t2; ")"]
      | PolynomialAST.Pow (v,n) -> String.concat "" ["("; Var.to_string v; "^"; string_of_int n; ")"]

    let rec atom_to_string (ex : AST.t) = match ex with
      | AST.Equal (p1, p2) -> String.concat " == " [(polynomial_to_string p1); (polynomial_to_string p2)]
      | AST.Neq (p1, p2) -> String.concat " <> " [(polynomial_to_string p1); (polynomial_to_string p2)]
      | AST.LessThan (p1, p2) -> String.concat " < " [(polynomial_to_string p1); (polynomial_to_string p2)]
      | AST.LessEqual (p1, p2) -> String.concat " <= " [(polynomial_to_string p1); (polynomial_to_string p2)]
      | AST.GreaterEqual (p1, p2) -> String.concat " >= " [(polynomial_to_string p1); (polynomial_to_string p2)]
      | AST.GreaterThan (p1, p2) -> String.concat " > " [(polynomial_to_string p1); (polynomial_to_string p2)]
                       
    let to_ast str =
         str
      |> Lexing.from_string
      |> Parser.polynomialConstraintAtom Lexer.read

    let to_atom str =
         str
      |> to_ast
      |> PolynomialConstraintsAtom.from_ast_atom

    let to_ast_and_back str =
         str
      |> to_ast
      |> atom_to_string

    let example_valuation = Valuation.from [(Var.of_string "x", Big_int.of_int 3);
                                            (Var.of_string "y", Big_int.of_int 5);
                                            (Var.of_string "z", Big_int.of_int 7)]
                                            
    let evaluate str =
         str
      |> to_ast
      |> PolynomialConstraintsAtom.from_ast_atom
      |> fun atom -> PolynomialConstraintsAtom.eval atom example_valuation
      
    let assert_equal_string =
        assert_equal ~cmp:String.equal

    let assert_true = assert_bool ""
    let assert_false b = assert_true (not b)
    
    let parser_tests =
        "Parser" >::: [
            "Positive Tests" >::: (
                List.map (fun (testname, expected, atom) ->
                testname >:: (fun _ -> assert_equal expected (to_ast_and_back atom)))
                        [
                        ("Constants LT", "42 < 42", " 42 < 42 ");
                        ("Constants LE", "42 <= 42", " 42 <= 42 ");
                        ("Constants GT", "42 > 42", " 42 > 42 ");
                        ("Constants GE", "42 >= 42", " 42 >= 42 ");
                        ("Constants EQ", "42 == 42", " 42 == 42 ");
                        ("Constants NEQ", "42 <> 42", " 42 <> 42 ");
                        ("Constant and Poly LT", "42 < ((x^2)+(((5*x)*y)*z))", " 42 < x^2+ 5*x*y*z ");
                        ("Constant and Poly LE", "42 <= ((x^2)+(((5*x)*y)*z))", " 42 <= x^2+ 5*x*y*z ");
                        ("Constant and Poly GT", "42 > ((x^2)+(((5*x)*y)*z))", " 42 > x^2+ 5*x*y*z ");
                        ("Constant and Poly GE", "42 >= ((x^2)+(((5*x)*y)*z))", " 42 >= x^2+ 5*x*y*z ");
                        ("Constant and Poly EQ", "42 == ((x^2)+(((5*x)*y)*z))", " 42 == x^2+ 5*x*y*z ");
                        ("Constant and Poly NEQ", "42 <> ((x^2)+(((5*x)*y)*z))", " 42 <> x^2+ 5*x*y*z ");
                        ("Poly and Poly LT", "(((x^5)+(y^6))+(-(z^3))) < ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                        ("Poly and Poly LE", "(((x^5)+(y^6))+(-(z^3))) <= ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                        ("Poly and Poly GT", "(((x^5)+(y^6))+(-(z^3))) > ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                        ("Poly and Poly GE", "(((x^5)+(y^6))+(-(z^3))) >= ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                        ("Poly and Poly EQ", "(((x^5)+(y^6))+(-(z^3))) == ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                        ("Poly and Poly NEQ", "(((x^5)+(y^6))+(-(z^3))) <> ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]
            );
            "Negative Tests" >::: (
                List.map (fun (testname, atom) ->
                    testname >:: (fun _ -> assert_raises (Lexer.SyntaxError (testname)) (fun _ -> to_ast_and_back atom)))
                            [
                            ("Unexpected char: =", "x = y");
                            ]
                );
        ]
    let constraints_atom_tests = 
        "ConstraintsAtom" >:::[
            ("is_lt" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_lt (to_atom atom))))
                        [
                            (true, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
            
            ("is_le" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_le (to_atom atom))))
                        [
                            (false, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (true,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
            
            ("is_gt" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_gt (to_atom atom))))
                        [
                            (false, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (true, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
                        
            ("is_ge" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_ge (to_atom atom))))
                        [
                            (false, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (true, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
            ("is_eq" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_eq (to_atom atom))))
                        [
                            (false, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (true, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
            ("is_neq" >:::
                List.map (fun (expected, atom) ->
                      atom >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.is_neq (to_atom atom))))
                        [
                            (false, " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                            (true, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ]);
                        
            ("(==)" >:::
                List.map (fun (expected, atom1, atom2) ->
                      atom1 >:: (fun _ -> assert_equal ~printer:Bool.to_string expected (PolynomialConstraintsAtom.(==) (to_atom atom1) (to_atom atom2))))
                        [
                            (true, " x^5+y^6-z^3 < x^2+ 5*x*y*z "," x^5+y^6-z^3 + a*b*c + 2*z^3 +7*y^17 - a*b*c - 2*z^3 -7*y^17 < x^2+ 5*x*y*z " );
                            (false,  " x^5+y^6-z^3 <= x^2+ 5*x*y*z ", "a*b*c + 2*z^3 +7*y^17 < a*b*c + 2*z^3 +7*y^17");
                            (false, " x^5+y^6-z^3 > x^2+ 5*x*y*z ", "a*b*c + 2*z^3 +7*y^17 < a*b*c + 2*z^3 +7*y^17");
                            (false, " x^5+y^6-z^3 >= x^2+ 5*x*y*z ", "a*b*c + 2*z^3 +7*y^17 < a*b*c + 2*z^3 +7*y^17");
                            (false, " x^5+y^6-z^3 == x^2+ 5*x*y*z ", "a*b*c + 2*z^3 +7*y^17 < a*b*c + 2*z^3 +7*y^17");
                            (false, " x^5+y^6-z^3 <> x^2+ 5*x*y*z ", "a*b*c + 2*z^3 +7*y^17 < a*b*c + 2*z^3 +7*y^17");
                        ]);

        ]
        
      end  
      
module StringIDPolynomialConstraints = PolynomialConstraintsTest(StringID)

let suite =
  "Suite" >::: [
      StringIDPolynomialConstraints.parser_tests;
      StringIDPolynomialConstraints.constraints_atom_tests;
(*      StringIDPolynomial.poly_tests;*)
    ]
                     
let () =
  run_test_tt_main suite

    