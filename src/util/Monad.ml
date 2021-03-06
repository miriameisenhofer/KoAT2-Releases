open Batteries

module Make
  (M :
    sig
      type 'a t
      val pure : 'a -> 'a t
      val bind : 'a t -> ('a -> 'b t) -> 'b t
    end) =

  struct
    type 'a t = 'a M.t

    let (>>=) = M.bind
    let (>>) f g = f >>= fun _ -> g

    let return = M.pure
    let pure = M.pure
    let bind = M.bind

    let when_m b f =
      if b then
        f
      else
        pure ()

    let rec sequence = function
      | [] -> pure []
      | (m::ms) ->
          m
          >>= fun v -> sequence ms
          >>= fun vs -> pure (v::vs)

    let mapM f =
      sequence % List.map f

  end