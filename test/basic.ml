external saucisse : int -> unit = "saucisse"
external morteau : float -> unit = "morteau"
external montbeliard : (float [@unboxed]) -> unit = "montbeliard_byte" "montbeliard"

external ( + ) : int -> int -> int = "%addint"
external ( - ) : int -> int -> int = "%subint"
external ( * ) : int -> int -> int = "%mulint"
external ( < ) : 'a -> 'a -> bool = "%lessthan"

external ( +. ) : float -> float -> float = "%addfloat"
external ( -. ) : float -> float -> float = "%subfloat"
external ( *. ) : float -> float -> float = "%mulfloat"
external ( /. ) : float -> float -> float = "%divfloat"

external opaque_identity : 'a -> 'a = "%opaque"

type 'a ref = { mutable contents : 'a }
external ref : 'a -> 'a ref = "%makemutable"
external ( ! ) : 'a ref -> 'a = "%field0"
external ( := ) : 'a ref -> 'a -> unit = "%setfield0"

let f x y z =
  x + y - z * x

let g x y =
  (f [@inlined never]) x x y

let h x =
  saucisse x

let i x =
  x, x

let j x =
  let (a, _) = x in
  a

let s () =
  "plop"

let () =
  h 3

let r = ref 0

let () = r := 1

let () = r := !r + 1

let () = saucisse !r

let rrr n =
  let r = ref n in
  r := !r * !r;
  saucisse !r
[@@inline never]
let () = rrr 3

let rec stuff x = stuff x

type a = A of (unit -> a)
let rec chose () = A chose

let v1 = 12.34
let v2 = 12l
let v3 = 12L
let v4 = 12n

let uuu x y z =
  x +. y *. x /. y -. z

type plop = { a : int; b : plop; c : int }
let rec a = { a = 1; b; c = 2 }
and b = { a = 10; b = a; c = 20 }

let () =
  h (opaque_identity 5);
  morteau (uuu 12.34 456. 2.);
  montbeliard 78.

let next x = x + 1
let n = (opaque_identity next) 2

let m =
  let a = (opaque_identity g) 2 in
  let () = opaque_identity () in
  let b = (opaque_identity a) 3 in
  h b;
  b

let mm =
  let b = (opaque_identity g) 2 3 in
  h b;
  b

let set_one x =
  let n = x + x in
  let gooo y = y + n in
  let () = () in
  gooo
[@@inline never]

let () = saucisse (set_one 12 5)

let set_two x =
  let n = x + x in
  let gougou y z = y + n + z in
  let () = () in
  gougou
[@@inline never]

let () = saucisse (set_two 12 5 1)

let set x =
  let rec f a =
    x + guu a
  and guu b =
    1 + f b
  in
  f 1
