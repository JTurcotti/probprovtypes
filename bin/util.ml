let compose f g x = g (f x)    
let id x = x


module type DeepHashT =
sig
  type t
  val deep_hash : t -> int
end

module type T = sig type t end

module Ord (T : T) = struct
  type t = T.t
  let compare = Stdlib.compare
end

let first = ref true
let check_first _ =
  if !first then (first := false; "") else ", "
let check_first_s s =
  if !first then (first := false; "") else s

type 't s_constr = 't Set.s_constr
type ('k, 'v) m_constr = ('k, 'v) Map.m_constr

let list_map_reduce map reduce unit l =
  match l with
  | [] -> unit
  | x :: l -> List.fold_right
                (compose map reduce) l (map x)

exception MapReduceExepectedNonempty

let list_map_reduce_nonempty map reduce l =
  match l with
  | [] -> raise MapReduceExepectedNonempty
  | x :: l -> List.fold_right
                (compose map reduce) l (map x)


module Set (T : T) =
struct
  include Set.Make(Ord(T))

  let map_reduce map reduce unit t =
    match choose_opt t with
    | None -> unit
    | Some el -> fold (compose map reduce) (remove el t) (map el)

  let map_reduce_nonempty map reduce t =
    match choose_opt t with
    | None -> raise MapReduceExepectedNonempty
    | Some el -> fold (compose map reduce) (remove el t) (map el)

                   
  let lift_format format_t infix unit: Format.formatter -> t -> unit =
    fun ff st ->
    if is_empty st then Format.fprintf ff "%s" unit
    else (
      let old = !first in
      first := true;
      iter (fun el ->
          Format.fprintf ff "%s" (check_first_s infix);
          Format.fprintf ff "%a" format_t el) st;
      first := old
    )

  let lift_hash hash_elt t =
    Hashtbl.hash (fold (fun el h -> h + hash_elt el) t 0)

  (**
    returns a set containining (op e1 e2) for all e1 in s1 and e2 in s2
  *)
  let prod op s1 s2 =
    map_reduce (fun e1 -> map (op e1) s2) union empty s1
end

module Map (T : T) =
struct
  include Map.Make(Ord(T))

  let from_elem_foo elems foo =
    List.fold_right (fun e -> add e (foo e)) elems empty

  let map_reduce map reduce unit t =
    match choose_opt t with
    | None -> unit
    | Some (k, v) -> fold (fun k v -> reduce (map k v)) (remove k t) (map k v)

  let map_reduce_nonempty map reduce t =
    match choose_opt t with
    | None -> raise MapReduceExepectedNonempty
    | Some (k, v) -> fold (fun k v -> reduce (map k v)) (remove k t) (map k v)



  let lift_format format_k format_v infix unit :
    Format.formatter -> 'a t -> unit =
    fun ff mp ->
    if is_empty mp then Format.fprintf ff "%s" unit
    else (
      let old = !first in
      first := true;
      iter (fun k v ->
          Format.fprintf ff "%s" (check_first_s infix);
          Format.fprintf ff "(%a:%a)" format_k k format_v v) mp;
      first := old
    )


end

type ('l, 'r) union_t = Left of 'l | Right of 'r

module Union (L : T) (R : T) =
struct
  module T =
  struct
    type t = (L.t, R.t) union_t
  end

  module UMap = Map(T)
  module USet = Set(T)
  module LMap = Map(L)
  module LSet = Set(L)
  module RMap = Map(R)
  module RSet = Set(R)

  let splitSet uset =
    USet.fold (fun e (lset, rset) ->
        match e with
        | Left e -> (LSet.add e lset, rset)
        | Right e -> (lset, RSet.add e rset))
      uset
      (LSet.empty, RSet.empty)

  let joinMap lmap rmap =
    LMap.fold (fun l v umap -> UMap.add (Left l) v umap) lmap
      (RMap.fold (fun r v umap -> UMap.add (Right r) v umap) rmap UMap.empty)

  let lift_format l_format r_format : Format.formatter -> T.t -> unit =
    fun ff ->
    function
    | Left l -> l_format ff l
    | Right r -> r_format ff r

  include T
end

module type Defer =
sig
  type t
  val get : unit -> t
end

(* guarantees that the Src Defer is only called once *)
module IdempotentDefer (Src : Defer) =
struct
  type t = Src.t

  let x_opt : t option ref = ref None

  let get _ =
    match !x_opt with
    | Some x -> x
    | None ->
      let x = Src.get () in
      let () = x_opt := Some x in
      x
end


let unicode_bar = "\u{0305}"
let unicode_bar_cond b = if b then "" else unicode_bar

module type Arithmetic =
sig
  type t

  val mult : t -> t -> t
  val add : t -> t -> t
  val sub : t -> t -> t
    
  val one : t
  val zero : t
end

module FloatArithmetic =
struct
  type t = float

  let mult a b = a *. b
  let add a b = a +. b
  let sub a b = a -. b
  let one = 1.
  let zero = 0.
end

let rec pow f i =
  if i = 0 then 1. else f *. (pow f (i - 1))

let list_last l =
  List.nth l (List.length l - 1) 
