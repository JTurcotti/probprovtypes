type func = Func of string
let func_to_string (Func s) = s

type local = Local of string
let local_to_string (Local s) = s

type arg = Arg of int * string
type ret = Ret of int * string

type branch = Branch of int
type label = Label of int
type call = Call of func * int

type aexp =
  | Var of local * label
  | Const of label
  | Binop of aexp * aexp * label
  | Unop of aexp * label
  | FApp of func * (aexp list) * label * call

type expr =
  | Skip
  | Cond of aexp * expr * expr * branch
  | Assign of local * aexp
  | FAssign of (local list) * aexp
  | Seq of expr * expr
  | Assert of local * aexp
  | AExp of aexp

type fdecl = {
  name: func;
  params: arg list;
  num_params: int;
  results: ret list;
  num_results: int;
  body: expr;
}

module FuncKey = struct
  type t = func
  let compare = Stdlib.compare
end

module FuncMap = Map.Make(FuncKey)
type program = Program of fdecl FuncMap.t

let lookup_func_opt f (Program mp) : fdecl option =
  FuncMap.find_opt f mp

exception LabelErr of string

(* This function takes a raw_program (see raw_expr)
   as parsed from source, and adds associates all of its
   conditionals with branches numbers and some AST nodes
   with label numbers

   TODO: add source locations to raw_expr's, and create a map
   from label numbers to source positions as part of this function
*)
let label_prog raw_prog =
  Raw_expr.(
    match raw_prog with
    | Raw_Program flist ->
      let is_func_name (f : string) =
        let rec is_in_list (t : raw_fdecl list) =
          match t with
          | [] -> false
          | f' :: t' -> f'.raw_name = f || is_in_list t' in
        is_in_list flist
      in
      (* we use this to ensure each branch gets a distinct index *)
      let branch_counter = ref 0 in
      (* we use this to ensure each line gets a distinct label *)
      let label_counter = ref 0 in
      (* we use this to ensure each call to the same function
         gets a distinct index *)
      let call_counter = ref FuncMap.empty in
      let next_branch _ =
        let () = branch_counter := !branch_counter + 1 in
        Branch(!branch_counter - 1) in
      let next_label _ =
        let () = label_counter := !label_counter + 1 in
        Label(!label_counter - 1) in
      let next_call f =
        let i = match FuncMap.find_opt f !call_counter with
          | None -> 0
          | Some i -> i in
        let () = call_counter := (FuncMap.add f (i + 1) !call_counter) in
        Call(f, i) in
    let rec label_aexp raw_aexpr =
      match raw_aexpr with
      | Raw_Var s -> Var(Local(s), next_label())
      | Raw_Const -> Const(next_label())
      | Raw_Binop (a, a') ->
        Binop(label_aexp a, label_aexp a', next_label())
      | Raw_Unop a -> Unop(label_aexp a, next_label())
      | Raw_FApp (s, a_list) ->
        let () = if not (is_func_name s) then
            raise (LabelErr (s ^ " not a function name")) else () in
        let f = Func(s) in
        FApp(f, List.map label_aexp a_list,
             next_label(), next_call f)
    in
    let rec label_expr raw_expr =
      (match raw_expr with
       | Raw_Skip -> Skip
       | Raw_Cond (a, e_t, e_f) ->
         Cond(label_aexp a, label_expr e_t, label_expr e_f,
              next_branch())
       | Raw_Assign (s, a) ->
         Assign(Local(s), label_aexp a)
       | Raw_FAssign (s_list, a) ->
         FAssign(List.map (fun s -> Local(s)) s_list, label_aexp a)
       | Raw_Seq (e, e') ->
         Seq(label_expr e, label_expr e')
       | Raw_Assert (s, a) ->
         Assert(Local(s), label_aexp a)
       | Raw_AExp a -> AExp(label_aexp a)) in
    let wrap_fold list transformer =
      let out, _ = List.fold_right (fun s (out, i) ->
          ((transformer i s) :: out, i - 1)) list ([], List.length list - 1) in out
    in
    let label_fdecl raw_fdecl =
      {
        name = Func(raw_fdecl.raw_name);
        params = wrap_fold raw_fdecl.raw_params (fun i s -> Arg(i, s));
        num_params = List.length raw_fdecl.raw_params;
        results = wrap_fold raw_fdecl.raw_results (fun i s -> Ret(i, s));
        num_results = List.length raw_fdecl.raw_results;
        body = label_expr raw_fdecl.raw_body;
      }
    in
    Program (List.fold_left (fun prog fdecl ->
        FuncMap.add (Func(fdecl.raw_name)) (label_fdecl fdecl) prog
      ) FuncMap.empty flist)
  )
