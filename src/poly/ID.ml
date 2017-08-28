open Batteries

module StringID =
  struct
    type t = String.t
    let (=~=) = String.equal
    let of_string str = str
    let to_string var = var
    let compare = String.compare
  end

module PrePostID =
  struct
    type t = Pre of StringID.t | Post of StringID.t
                                       
    let (=~=) a b = match (a, b) with
      | (Pre _, Post _) -> false
      | (Post _, Pre _) -> false
      | (Pre id1, Pre id2) -> id1 == id2
      | (Post id1, Post id2) -> id1 == id2
                              
    let of_string str =
      if String.ends_with str "'" then
        Post (String.rchop str)
      else Pre str
      
    let to_string = function
      | Pre str -> str
      | Post str -> str ^ "'"
                  
    let compare a b = raise (Failure "compare for PrePostID not yet implemented")
  end