open Context
open Expr
  
let aee_repr (CallEvent(Call(Func(s), i_f), Arg(i_a, _), Ret(i_r, _))) =
  Printf.sprintf "ϕ⟨%s%s⟩ₐ%sʳ%s"
    s (int_subscript_repr i_f)
    (int_subscript_repr i_a)
    (int_superscript_repr i_r)

let aee_conj_repr aee_conj =
  if AEEConjunctiveSet.is_empty aee_conj then
    "1"
  else
    AEEConjunctiveSet.fold
      (fun aee s -> (aee_repr aee) ^ s) aee_conj ""

let external_event_repr ext_ev =
  if AEEDNFSet.is_empty ext_ev then "0" else
    let fst = AEEDNFSet.choose ext_ev in
    AEEDNFSet.fold
      (fun aee_conj ->
         Printf.sprintf "%s + %s" (aee_conj_repr aee_conj))
      (AEEDNFSet.remove fst ext_ev) (aee_conj_repr fst)

let aie_repr (AIE(Branch(i), dir)) =
  if dir then
    Printf.sprintf "π%s" (int_subscript_repr i)
  else
    Printf.sprintf "π\u{0305}%s" (int_subscript_repr i)
    

let internal_event_repr int_ev =
  if BranchMap.is_empty int_ev then
    "1"
  else
    BranchMap.fold
      (fun b dir s -> (aie_repr (AIE(b, dir)) ^ s)) int_ev ""

let map_repr
    is_empty choose remove fold
    zero_repr k_repr v_repr k_combine_v_str kv_combine_str map =
  let kv_repr k v =
    Printf.sprintf k_combine_v_str (k_repr k) (v_repr v) in
  if is_empty map then zero_repr else
    let (fst_k, fst_v) = choose map in
    fold (fun k v -> Printf.sprintf kv_combine_str (kv_repr k v))
      (remove fst_k map) (kv_repr fst_k fst_v)

let event_repr =
  map_repr
    IEMap.is_empty IEMap.choose IEMap.remove IEMap.fold
    "0" internal_event_repr external_event_repr "%s*%s" "%s ∨ %s" 

let site_repr = function
  | LabelSite(Label(i)) -> 
    Printf.sprintf "L%s" (int_subscript_repr i)
  | CallSite (Call (Func f_s, f_i), Ret (r_i, _)) -> 
    Printf.sprintf "Β⟨%s%s⟩ʳ%s"
      f_s (int_subscript_repr f_i) (int_superscript_repr r_i)
  | ArgSite (Arg (i, s)) -> 
    Printf.sprintf "α%s⟨%s⟩" (int_subscript_repr i) s
  | PhantomRetSite (Ret (i, s)) ->
    Printf.sprintf "ρ%s⟨%s⟩" (int_subscript_repr i) s

let blame_repr =
  map_repr
    SiteMap.is_empty SiteMap.choose SiteMap.remove SiteMap.fold
    "0" site_repr event_repr "\t%s ↦ %s" "%s\n%s"

let local_repr (Local s) = s

let context_repr =
  map_repr
    LocalMap.is_empty LocalMap.choose LocalMap.remove LocalMap.fold
    "∅" local_repr blame_repr "%s ↦ {\n%s}" "%s\n%s"
  
  let blame_ex = blame_repr (blame_event_conj (blame_one (LabelSite(Label(10)))) (event_disj
                                                                                    (event_internal_conj (AIE(Branch(5), false)) event_one)
                                                                                    (event_internal_conj (AIE(Branch(6), true)) event_one)))