(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt

module Log = Log.Make(struct let section = "RO" end)

module type S = sig
  type t
  type key
  type value
  val create: unit -> t Lwt.t
  val read: t -> key -> value option Lwt.t
  val read_exn: t -> key -> value Lwt.t
  val mem: t -> key -> bool Lwt.t
  val list: t -> key list -> key list Lwt.t
  val dump: t -> (key * value) list Lwt.t
end

module type BINARY = S with type key = Cstruct.t and type value = Cstruct.t

module type MAKER = functor (K: Tc.I0) -> functor (V: Tc.I0) ->
  S with type key = K.t and type value = V.t

module Binary  (S: BINARY) (K: Tc.I0) (V: Tc.I0) = struct

  type t = S.t

  type key = K.t

  type value = V.t

  let to_raw = Tc.write_cstruct (module K)
  let of_raw = Tc.read_cstruct (module K)

  let create () =
    S.create ()

  let read t key =
    S.read t (to_raw key) >>= function
    | None    -> return_none
    | Some ba -> return (Some (Tc.read_cstruct (module V) ba))

  let read_exn t key =
    read t key >>= function
    | Some v -> return v
    | None   -> fail (Ir_uid.Unknown (Tc.show (module K) key))

  let mem t key =
    S.mem t (to_raw key)

  let list t keys =
    let keys = List.map to_raw keys in
    S.list t keys >>= fun ks ->
    let ks = List.map of_raw ks in
    return ks

  let dump t =
    S.dump t >>= fun l ->
    Lwt_list.fold_left_s (fun acc (s, ba) ->
        let v = Tc.read_cstruct (module V) ba in
        return ((of_raw s, v) :: acc)
      ) [] l

end
