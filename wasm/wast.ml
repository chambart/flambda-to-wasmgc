open Wstate
open Wident
module Expr = Wexpr
module Type = Wtype

module Cst = struct
  type t =
    | Int of int64
    | Float of float
    | String of string
    | Atom of string
    | Node of
        { name : string
        ; args_h : t list
        ; args_v : t list
        ; force_paren : bool
        }

  let print_lst f ppf l =
    Format.pp_print_list ~pp_sep:(fun ppf () -> Format.fprintf ppf "@ ") f ppf l

  let rec emit ppf = function
    | Int i -> Format.fprintf ppf "%Li" i
    | Float f -> Format.fprintf ppf "%h" f
    | String s -> Format.fprintf ppf "\"%s\"" s
    | Atom s -> Format.pp_print_string ppf s
    | Node { name; args_h; args_v; force_paren } -> begin
      match (args_h, args_v) with
      | [], [] ->
        if force_paren then Format.fprintf ppf "(%s)" name
        else Format.pp_print_string ppf name
      | _ ->
        Format.fprintf ppf "@[<v 2>@[<hov 2>";
        Format.fprintf ppf "(%s@ %a@]" name (print_lst emit) args_h;
        ( match args_v with
        | [] -> ()
        | _ -> Format.fprintf ppf "@ %a" (print_lst emit) args_v );
        Format.fprintf ppf ")@]"
    end

  let nodev name args =
    Node { name; args_h = []; args_v = args; force_paren = false }

  let nodehv name args_h args_v =
    Node { name; args_h; args_v; force_paren = false }

  let node name args =
    Node { name; args_h = args; args_v = []; force_paren = false }

  let node_p name args =
    Node { name; args_h = args; args_v = []; force_paren = true }

  let atom name = Atom name
end

module C = struct
  open Cst

  let ( !$ ) v = atom (Printf.sprintf "$%s" v)

  let type_name v = atom (Type.Var.name v)

  let global name export_name typ descr =
    match export_name with
    | None -> node "global" ([ !$name; typ ] @ descr)
    | Some export_name ->
      node "global"
        ([ !$name; node "export" [ String export_name ]; typ ] @ descr)

  let global_import name typ module_ import_name =
    node "global"
      [ !$name; node "import" [ String module_; String import_name ]; typ ]

  let reft name = node "ref" [ type_name name ]

  let struct_new_canon typ fields =
    let name =
      match mode with
      | Binarien -> "struct.new"
      | Reference -> "struct.new_canon"
    in
    node name (type_name typ :: fields)

  let array_new_canon_fixed typ size args =
    match mode with
    | Binarien -> node "array.new" ([ type_name typ ] @ args)
    | Reference ->
      node "array.new_canon_fixed"
        ([ type_name typ; Int (Int64.of_int size) ] @ args)

  let int i =
    (* XXX TODO remove this is wrong,
       but this allows to avoid problems with max_int for now... *)
    let i =
      Int64.of_int32 (Int32.of_int i)
    in
    Int i

  let string s = String s

  let i32_ i = node "i32.const" [ int i ]

  let i32 i = node "i32.const" [ Int (Int64.of_int32 i) ]

  let i64 i = node "i64.const" [ Int i ]

  let f64 f = node "f64.const" [ Float f ]

  let i31_new i = node "i31.new" [ i ]

  let drop arg = node "drop" [ arg ]

  let drop' = atom "drop"

  let ref_func f = node "ref.func" [ !$(Func_id.name f) ]

  let global_get g = node "global.get" [ !$(Global.name g) ]

  let local_get l = node "local.get" [ !$(Expr.Local.name l) ]

  let local_set l arg = node "local.set" [ !$(Expr.Local.name l); arg ]

  let local_set' l = node "local.set" [ !$(Expr.Local.name l) ]

  let struct_get typ field arg =
    node "struct.get" [ type_name typ; int field; arg ]

  let array_len _typ arg = node "array.len" [ (* type_name typ;  *) arg ]

  let array_get typ args = node "array.get" (type_name typ :: args)

  let sx_name (sx : Expr.sx) = match sx with S -> "s" | U -> "u"

  let array_get_packed typ extend args =
    node (Printf.sprintf "array.get_%s" (sx_name extend)) (type_name typ :: args)

  let array_set typ args = node "array.set" (type_name typ :: args)

  let struct_get_packed extend typ field arg =
    node
      (Printf.sprintf "struct.get_%s" (sx_name extend))
      [ type_name typ; int field; arg ]

  let struct_set typ field block value =
    node "struct.set" [ type_name typ; int field; block; value ]

  let return_call_ref typ args = node "return_call_ref" ([ type_name typ ] @ args)

  let call_ref typ args = node "call_ref" ([ type_name typ ] @ args)

  let call_ref' typ = node "call_ref" [ type_name typ ]

  let return_call func args = node "return_call" ([ !$(Func_id.name func) ] @ args)

  let call func args = node "call" ([ !$(Func_id.name func) ] @ args)

  let ref_cast typ arg =
    let name =
      match mode with Binarien -> "ref.cast_static" | Reference -> "ref.cast"
    in
    node name ([ type_name typ ] @ arg)

  let declare_func f =
    node "elem" [ atom "declare"; atom "func"; !$(Func_id.name f) ]

  let rec type_atom (t : Type.atom) =
    match t with
    | I8 -> atom "i8"
    | I16 -> atom "i16"
    | I32 -> atom "i32"
    | I64 -> atom "i64"
    | F64 -> atom "f64"
    | Rvar v -> reft v
    | Tuple l -> node "" (List.map type_atom l)

  let local l t = node "local" [ !$(Expr.Local.var_name l); type_atom t ]

  let param p t = node "param" [ !$(Param.name p); type_atom t ]

  let param_t t = node "param" [ type_atom t ]

  let result t = node "result" [ type_atom t ]

  let results t = node_p "result" (List.map type_atom t)

  let func ~name ~params ~result ~locals ~body =
    let fields =
      [ !$(Func_id.name name); node "export" [ String (Func_id.name name) ] ]
      @ params @ result @ locals
    in
    nodehv "func" fields body

  let field f = node "field" [ node "mut" [ type_atom f ] ]

  let struct_type fields = node "struct" (List.map field fields)

  let array_type f = node "array" [ node "mut" [ type_atom f ] ]

  let func_type ?name params res =
    let name =
      match name with None -> [] | Some name -> [ !$(Func_id.name name) ]
    in
    let res = List.map result res in
    node "func" (name @ List.map param_t params @ res)

  let if_then_else typ cond if_expr else_expr =
    let nopise e =
      match mode with
      | Reference -> e
      | Binarien -> ( match e with [] -> [ node_p "nop" [] ] | _ -> e )
    in
    let if_expr = nopise if_expr in
    let else_expr = nopise else_expr in
    node "if"
      [ results typ; cond; node_p "then" if_expr; node_p "else" else_expr ]

  let group_block result body = nodehv "block" [ results result ] body

  let block id result body =
    nodehv "block" [ !$(Block_id.name id); results result ] body

  let loop id result body =
    nodehv "loop" [ !$(Block_id.name id); results result ] body

  let br id args =
    match (mode, args) with
    | Binarien, _ :: _ :: _ ->
      node "br" [ !$(Block_id.name id); node "tuple.make" args ]
    | _ -> node "br" ([ !$(Block_id.name id) ] @ args)

  let br' id = node "br" [ !$(Block_id.name id) ]

  let br_on_cast id typ arg =
    match mode with
    | Binarien -> begin
      match typ with
      | Type.Var.I31 ->
        node "drop" [ node "br_on_i31" [ !$(Block_id.name id); arg ] ]
      | _ ->
        node "br_on_cast_static" [ !$(Block_id.name id); type_name typ; arg ]
    end
    | Reference ->
      node "br_on_cast" [ !$(Block_id.name id); type_name typ; arg ]

  let br_if id cond = node "br_if" [ !$(Block_id.name id); cond ]

  let br_table cond cases =
    node "br_table" (List.map (fun id -> !$(Block_id.name id)) cases @ [ cond ])

  let type_ name descr = node "type" [ type_name name; descr ]

  let unreachable = node_p "unreachable" []

  let pop typ = node "pop" [ type_atom typ ]

  let throw e = node "throw" [ e ]

  let try_ ~body ~typ ~handler =
    node "try" [ node "do" body; node "catch" (type_atom typ :: handler) ]

  let sub name descr =
    match mode with
    | Binarien -> descr
    | Reference -> node "sub" [ type_name name; descr ]

  let tuple_make fields = node "tuple.make" fields

  let tuple_extract field tuple = node "tuple.extract" [ int field; tuple ]

  let rec_ l = node "rec" l

  let import module_ name e = node "import" [ String module_; String name; e ]

  let start f = node "start" [ !$(Func_id.name f) ]

  let module_ m = nodev "module" m

  let register name = node "register" [ String name ]
end
