open Batteries
open Polynomials


let list_string vec = 
  vec
  |> List.map OurInt.to_string
  |> String.concat ", "

let make_string str = "\"" ^ str ^ "\""

module ProbUpdate =
  struct
    type t = {
      probability: Num.t;
      update: OurInt.t list;
    }
    let from prob up = 
      {
        probability = prob;
        update = up;
      }

    let probability u =
      u.probability
    
    let update u =
      u.update

    let to_string pu =
      Num.to_string pu.probability ^ ":(" ^ list_string pu.update ^ ")"
  end

module ExactProgram =
  struct
    type t = {
      guardvector: OurInt.t list;
      guardvalue: OurInt.t;
      updates: ProbUpdate.t list;
      directtermination: ProbUpdate.t option;
      precision: OurInt.t option;
    }
    let from guardvec guardval up dirterm prec =
      {
        guardvector = guardvec;
        guardvalue = guardval;
        updates = up;
        directtermination = dirterm;
        precision = prec;
      }
      let guardvector ep =
        ep.guardvector

      let guardvalue ep =
        ep.guardvalue
      
      let updates ep =
        ep.updates
      
      let directtermination ep =
        ep.directtermination
      
      let precision ep =
        ep.precision
      
      let updates_to_string ups =
        ups
        |> List.map ProbUpdate.to_string
        |> String.concat " :+: "
      
      let to_string ep =
        let guard_vec_str = "(GUARDVEC " ^ list_string ep.guardvector ^ ")\n" in
        let guard_val_str = "(GUARDVEC " ^ OurInt.to_string ep.guardvalue ^ ")\n" in
        let update_str = "(UPDATES " ^ updates_to_string ep.updates ^ ")\n" in
        let dir_term_str = Option.map (fun dterm -> "(DIRECTTERMINATION " ^ ProbUpdate.to_string dterm ^ ")\n") (ep |> directtermination) in
        let prec_str = Option.map (fun prec -> "(PRECISION " ^ OurInt.to_string prec ^ ")\n") (ep |> precision) in
        guard_vec_str ^ guard_val_str ^ update_str ^ (dir_term_str |? "") ^ (prec_str |? "")
      
      let is_valid ?logger ep =
        let log_str str =
          Option.map (fun logger -> Logger.log logger Logger.DEBUG (fun () -> str, [])) logger
          |> ignore
        in
        let prob_greater_zero = 
          ((ep |> directtermination |> Option.map ProbUpdate.probability |> Option.map (Num.(<=/) Num.zero)) |? true) &&
          (ep |> updates |> List.map ProbUpdate.probability |> List.for_all (Num.(<=/) Num.zero))
          |> tap (fun res ->  if Bool.neg res then
                                log_str "Not all Probabilities are greater than zero.")
        in
        let equals_one = 
          Num.(+) 
          ((ep |> directtermination |> Option.map ProbUpdate.probability) |? Num.zero)
          (ep |> updates |> List.map ProbUpdate.probability |> List.fold_left Num.(+) Num.zero)
          |> Num.equal Num.one
          |> tap (fun res ->  if Bool.neg res then
                                log_str "Probabilities do not add up to one.")
        in
        let same_vec_len =
          let update_len =
            ep |> updates |> List.first |> ProbUpdate.update |> List.length
          in
          let same_update_len =
          ep |> updates |> List.map ProbUpdate.update |> List.map List.length
          |> List.for_all (Int.equal update_len)
          |> tap (fun res ->  if Bool.neg res then
                                log_str "Not all update vectors have the same length.")
          in
          let same_term_len = 
            ep |> directtermination 
            |> Option.map (fun dterm -> dterm |> ProbUpdate.update |> List.length)
            |> Option.map_default (Int.equal update_len) true
            |> tap (fun res ->  if Bool.neg res then
                                log_str "Termination vector has the wrong length.")
          in
          same_update_len && same_term_len
        in
        prob_greater_zero && equals_one && same_vec_len
      
      let to_sage ep =
        let positional = 
          [
            "(" ^ (ep |> guardvector |> list_string) ^ ")";
            ep |> guardvalue |> OurInt.to_string;
            ep |> updates |> updates_to_string
          ]
          |> List.map make_string
        in
        let optional =
          [
            ep |> directtermination |> Option.map ProbUpdate.to_string |> Option.map make_string |> Option.map (fun str -> "--dirterm " ^ str);
            ep |> precision |> Option.map OurInt.to_string |> Option.map make_string |> Option.map (fun str -> "--prec " ^ str)
          ]
          |> List.filter Option.is_some
          |> List.map Option.get
        in
        positional @ optional
        |> String.concat " "
        
  end