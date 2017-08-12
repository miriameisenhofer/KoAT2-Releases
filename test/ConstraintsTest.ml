open Batteries
open ID
open OUnit2
open PolyTypes
open ConstraintTypes
   
module Parser =
  struct
    module Reader = Readers.Make(Mocks.TransitionGraph)

    let to_constr_and_back str =
         str
      |> Reader.read_constraint
      |> Mocks.TransitionGraph.Transition_.Constraint_.to_string

    
    let tests =
        "Parser" >::: [
            "Positive Tests" >::: (
                List.map (fun (testname, expected, atom) ->
                testname >:: (fun _ -> assert_equal expected (to_constr_and_back atom)))
                        [
                        ("Constants LT", "42 < 42", " 42 < 42 ");
                        ("Constants LE", "42 <= 42", " 42 <= 42 ");
                        ("Constants GT", "42 > 42", " 42 > 42 ");
                        ("Constants GE", "42 >= 42", " 42 >= 42 ");
                        ("Constants EQ", "42 == 42", " 42 == 42 ");
                        ("Constants NEQ", "42 <> 42", " 42 <> 42 ");
                        ("Constants ", "42 < 42 /\ 1 >= 0 /\ 2 <= 4 /\ 6 == 7", " 42 < 42 && 1 >= 0 && 2 <= 4 && 6 == 7");
                        
                        ("Constant and Poly LT", "42 < ((x^2)+(((5*x)*y)*z))", " 42 < x^2+ 5*x*y*z ");
                        ("Constant and Poly LE", "42 <= ((x^2)+(((5*x)*y)*z))", " 42 <= x^2+ 5*x*y*z ");
                        ("Constant and Poly GT", "42 > ((x^2)+(((5*x)*y)*z))", " 42 > x^2+ 5*x*y*z ");
                        ("Constant and Poly GE", "42 >= ((x^2)+(((5*x)*y)*z))", " 42 >= x^2+ 5*x*y*z ");
                        ("Constant and Poly EQ", "42 == ((x^2)+(((5*x)*y)*z))", " 42 == x^2+ 5*x*y*z ");
                        ("Constant and Poly NEQ", "42 <> ((x^2)+(((5*x)*y)*z))", " 42 <> x^2+ 5*x*y*z ");
                        ("Constants and Variables", "x > 0 /\ y < 3", "x > 0 && y < 3");
                        ("Constants and Polynomials", "(x*x) > 0 /\ (y^2) < 3 /\ ((x^2)+(((5*x)*y)*z)) <> 17", "x*x > 0 && y^2 < 3 && x^2+ 5*x*y*z <> 17");
                        
                        
                        ("Poly and Poly LT", "(((x^5)+(y^6))+(-(z^3))) < ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 < x^2+ 5*x*y*z ");
                        ("Poly and Poly LE", "(((x^5)+(y^6))+(-(z^3))) <= ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 <= x^2+ 5*x*y*z ");
                        ("Poly and Poly GT", "(((x^5)+(y^6))+(-(z^3))) > ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 > x^2+ 5*x*y*z ");
                        ("Poly and Poly GE", "(((x^5)+(y^6))+(-(z^3))) >= ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 >= x^2+ 5*x*y*z ");
                        ("Poly and Poly EQ", "(((x^5)+(y^6))+(-(z^3))) == ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 == x^2+ 5*x*y*z ");
                        ("Poly and Poly NEQ", "(((x^5)+(y^6))+(-(z^3))) <> ((x^2)+(((5*x)*y)*z))", " x^5+y^6-z^3 <> x^2+ 5*x*y*z ");
                        ("Polynomial Constraints", "(((x^5)+(y^6))+(-(z^3))) <> ((x^2)+(((5*x)*y)*z)) /\ (z^3) < (x+y)","x^5+y^6-z^3 <> x^2+ 5*x*y*z && z^3 < x +y" )

                        ]
            );
            "Negative Tests" >::: 
            (
                List.map (fun (testname, atom) ->
                    testname >:: (fun _ -> assert_raises (Reader.Lexer.SyntaxError (testname)) (fun _ -> to_constr_and_back atom)))
                            [
                            ("Unexpected char: =", "x = y");
                            ]
                );
                
            
        ]
        
  end
  
module Methods (C : Constraint) =
  struct
    module Reader = Readers.Make(TransitionGraph.MakeTransitionGraph(TransitionGraph.MakeTransition(C)))

    module Atom = C.Atom_
    module Polynomial = Atom.Polynomial_
                     
    let to_constr_and_back str =
         str
      |> Reader.read_constraint
      |> C.to_string

    let example_valuation = Polynomial.Valuation_.from [(Polynomial.Var.of_string "x", Polynomial.Value.of_int 3);
                                                        (Polynomial.Var.of_string "y", Polynomial.Value.of_int 5);
                                                        (Polynomial.Var.of_string "z", Polynomial.Value.of_int 7)]
                          
    let example_renaming = Polynomial.RenameMap_.from [(Polynomial.Var.of_string "x"), (Polynomial.Var.of_string "a");
                                                       (Polynomial.Var.of_string "y"), (Polynomial.Var.of_string "b");
                                                       (Polynomial.Var.of_string "z"), (Polynomial.Var.of_string "c")]
    
    
    let varlist_to_string varl =
        varl
        |> List.map Polynomial.Var.to_string
        |> String.concat ","
                                    
    let rename str =
         str
      |> Reader.read_constraint
      |> fun constr -> C.rename constr example_renaming
      
    let evaluate str =
         str
      |> Reader.read_constraint
      |> fun constr -> C.eval_bool constr example_valuation
      
    let assert_equal_string =
        assert_equal ~cmp:String.equal

    let assert_true = assert_bool ""
    let assert_false b = assert_true (not b)
    
    
    let rec equal_varlist varl1 varl2 = 
        let sort1 = (List.sort Polynomial.Var.compare varl1) in
        let sort2 = (List.sort Polynomial.Var.compare varl2) in
        match (sort1,sort2) with 
        | ([],[]) -> true
        | (h1::t1, h2::t2) -> (Polynomial.Var.(==) h1 h2) && (equal_varlist t1 t2)
        | (_,_) -> false
        
    let assert_equal_varlist = 
        
        assert_equal ~cmp:equal_varlist
        
    let rec equal_constr constr1 constr2 = 
        match (constr1,constr2) with 
        | ([],[]) -> true
        | (h1::t1, h2::t2) -> (C.Atom_.(==) h1 h2) && (equal_constr t1 t2)
        | (_,_) -> false
            
    let assert_equal_constr = 
    
        assert_equal ~cmp:equal_constr ~printer:C.to_string
        
    let tests = 
        (*let default_poly_l_1 = "x^5+y^6-z^3" in
        let default_poly_r_1 = "x^2+ 5*x*y*z" in
        let default_poly_l_2 = "x^5+y^6-z^3 + a*b*c + 2*z^3 +7*y^17 - a*b*c - 2*z^3 -7*y^17" in*)

        "Constraints" >:::[

            ("get_variables" >:::
                List.map (fun (expected, constr) ->
                      constr >:: (fun _ -> assert_equal_varlist ~printer:varlist_to_string expected (C.vars (Reader.read_constraint constr) )))
                        [
                            ([Polynomial.Var.of_string "x"], " x^3+2*x -1 < x^5 && x <> 0 && 3 > 2 " );
                            ([Polynomial.Var.of_string "x"; Polynomial.Var.of_string "y"; Polynomial.Var.of_string "z"], " x^5+y^6-z^3 + a*b*c + 2*z^3 +7*y^17 - a*b*c - 2*z^3 -7*y^17 < x^2+ 5*x*y*z && x > 0 && y >= 0 && z <= 4" );

                        ]);
                        
            ("rename_vars" >:::
                List.map (fun (expected, constr) ->
                      constr >:: (fun _ -> assert_equal_constr (Reader.read_constraint expected) (rename constr )))
                        [
                            ("5 <= 5", " 5 <= 5 " );
                            ("a == a", "x == x" );
                            ("a < a ^ 2 + 2 * a * b", "x < x ^ 2 + 2 * x * y" );
                            ("a^5+b^6-c^3 <> a * b * c + a^2 " , "x^5+y^6-z^3 <> x * y * z + x^2 ");
                            ("a^2 * b^2 < 7", "x^2 * y^2 < 7");
                            ("a == a && b < c", "x == x && y < z" );
                            (" a^2 > 0 && b^2-2*c^3 <> a^5 && 2 < 5 && 2 *a < a + b + c  ", "x^2 > 0 && y^2 -2*z^3 <> x^5 && 2 < 5 && 2*x < x+y+z ")

                        ]);
            ("eval_bool" >:::
                List.map (fun (expected, constr) ->
                      constr >:: (fun _ ->  assert_equal ~printer:Bool.to_string (expected) (evaluate constr )))
                        [
                            (true, " 5 <= 5 " );
                            (true, "x == x" );
                            (true,"x < x ^ 2 + 2 * x * y" );
                            (false, "x^5+y^6-z^3 == x * y * z + x^2 ");
                            (false , "x^2 * y^2 < 7");
                            (true , "2 < 3 && 3 < 4 && 4 < 5");
                            (false, "3 == 3 && 2 == 2 && 1 == 0");
                            (false, "x^2 > 0 && y^3 < 100 && x^5+y^6-z^3 <> x^2+ 5*x*y*z");
                            (true, "x^2 > 0 && y^3 < 126 && x^5+y^6-z^3 <> x^2+ 5*x*y*z");
                        ]);
        ]
        
      end
