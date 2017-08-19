open Batteries
open PolyTypes
open ConstraintTypes

module Make(P : Polynomial) =
(*Polynomial Constraints of the form p1<p2, p1<=p2, etc. Conjunctions of these constraints form the real constraints*)
struct
    module Polynomial_ = P

    module Comparator =
      struct
        type t = GT | GE | LT | LE | NEQ | EQ

        let values = [GT; GE; LT; LE; NEQ; EQ]

        (* Helper function *)
        let is_inverted (comp1 : t) (comp2 : t) =
          match (comp1, comp2) with
          | (GT, LT) -> true
          | (GE, LE) -> true
          | (LT, GT) -> true
          | (LE, GE) -> true
          | (EQ, EQ) -> true
          | (NEQ, NEQ) -> true
          | (_,_) -> false

        let to_string = function
          | GT -> ">"
          | GE -> ">="
          | LT -> "<"
          | LE -> "<="
          | EQ -> "="
          | NEQ -> "!="
               
        let to_function =
          let open P.Value.Compare in function
          | GT -> (>)
          | GE -> (>=)
          | LT -> (<)
          | LE -> (<=)
          | EQ -> (=)
          | NEQ -> (<>)
      end
           
    type t = P.t * Comparator.t * P.t


    let mk comp poly1 poly2 =
      (poly1, comp, poly2)

    let mk_gt = mk Comparator.GT
    let mk_ge = mk Comparator.GE
    let mk_lt = mk Comparator.LT
    let mk_le = mk Comparator.LE
    let mk_eq = mk Comparator.EQ
    let mk_neq = mk Comparator.NEQ


    let comparator = function 
      | (_,comparator,_) -> comparator
                 
    let fst = function
      | (fst,_,_) -> fst

    let snd = function
      | (_,_,snd) -> snd

    let (=~=) atom1 atom2 =
      match (atom1, atom2) with
      | ((p1, comp1, q1), (p2, comp2, q2)) ->
         Comparator.(comp1 == comp2) && P.(p1 =~= p2 && q1 =~= q2)
            
    let to_string = function
      | (p1, comp, p2) -> String.concat " " [P.to_string p1; Comparator.to_string comp; P.to_string p2]
        
    (* Helper function *)                        
    let is comp atom =
      Comparator.(comparator atom == comp)

    let is_gt = is Comparator.GT
    let is_ge = is Comparator.GE
    let is_lt = is Comparator.LT
    let is_le = is Comparator.LE
    let is_eq = is Comparator.EQ
    let is_neq = is Comparator.NEQ
               
    let is_same atom1 atom2 =
      Comparator.(comparator atom1 == comparator atom2)
            
    let is_linear atom =
      Polynomial_.is_linear (fst atom) && Polynomial_.is_linear (snd atom)
        
    let is_redundant atom1 atom2 =
      match (atom1, atom2) with
      | ((p1, comp1, q1), (p2, comp2, q2)) ->
         (Comparator.is_inverted comp1 comp2 && P.(p1 =~= q2 && q1 =~= p2)) || atom1 =~= atom2 
        
    let vars = function
      | (p1, _, p2) -> Set.union (P.vars p1) (P.vars p2)
        

    let rename atom varmapping =
      match atom with
      | (p1, comp, p2) -> (P.rename varmapping p1, comp, P.rename varmapping p2)

    (* TODO It's maybe possible to compare polynomials without full evaluation *)
    (* However, there are probably more expensive operations *)
    let eval_bool atom valuation =
      match atom with
      | (p1, comp, p2) -> (Comparator.to_function comp) (P.eval p1 valuation) (P.eval p2 valuation)

    (* Helper function *)                        
    let simplify = function
      | (p1, comp, p2)-> (P.simplify p1, comp, P.simplify p2)
     
    let normalise atom =
      let atom_in = simplify atom in
        let fst_in = fst atom_in in
        let snd_in = snd atom_in in
          let fst_min_snd = Polynomial_.sub fst_in snd_in in
          let const_part = Polynomial_.from_constant (Polynomial_.constant fst_min_snd) in
          let new_left = Polynomial_.sub fst_min_snd const_part in
          let new_right = Polynomial_.neg const_part in
          (new_left, (comparator atom), new_right)
                         
    let remove_strictness = function
      | (p1, Comparator.GT, p2)-> mk_ge p1 (P.add p2 P.one)
      | (p1, Comparator.LT, p2)-> mk_le p1 (P.sub p2 P.one)
      | atom -> atom

end
