(*s: semgrep/core/Pattern.ml *)
(*s: pad/r2c copyright *)
(* Yoann Padioleau
 *
 * Copyright (C) 2019-2021 r2c
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
*)
(*e: pad/r2c copyright *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* A semgrep pattern.
 *
 * A pattern is represented essentially as an AST_generic.any
 * where special constructs are now allowed (e.g., Ellipsis),
 * where certain identifiers are metavariables (e.g., $X), or
 * where certain strings are ellipsis or regular expressions
 * (e.g., "=~/foo/").
 *
 * See also Metavariable.ml.
*)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(*s: type [[Pattern.t]] *)
(* right now Expr/Stmt/Stmts/Types/Patterns/Partial and probably
 * more are supported *)
type t = AST_generic.any
[@@deriving show, eq]
(*e: type [[Pattern.t]] *)

let regexp_regexp_string = "^=~/\\(.*\\)/\\([mi]?\\)$"
let is_regexp_string s =
  s =~ regexp_regexp_string

let is_special_string_literal str =
  str = "..." ||
  is_regexp_string str

let is_js lang =
  match lang with
  | Some (Lang.Javascript | Lang.Typescript) -> true
  | Some _ -> false
  | None -> true

let is_special_identifier ?lang str =
  Metavariable.is_metavar_name str ||
  (* emma: a hack because my regexp skills are not great *)
  (String.length str > 4 && (Str.first_chars str 4) = "$...") ||

  (* in JS field names can be regexps *)
  (is_js lang && is_regexp_string str) ||
  (* ugly hack that we then need to handle also here *)
  str = AST_generic.special_multivardef_pattern ||
  (* ugly: because ast_js_build introduce some extra "!default" ids *)
  (is_js lang && str = Ast_js.default_entity) ||
  (* parser_java.mly inserts some implicit this *)
  (lang = Some Lang.Java && str = "this") ||
  (* TODO: PHP converts some Eval in __builtin *)
  (lang = Some Lang.PHP && (str =~ "__builtin__*"))

(*e: semgrep/core/Pattern.ml *)
