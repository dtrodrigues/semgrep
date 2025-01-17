(*s: semgrep/matching/Matching_generic.mli *)

(*s: type [[Matching_generic.tin]] *)
(* tin is for 'type in' and tout for 'type out' *)
(* incoming environment *)
type tin = {
  mv : Metavariable_capture.t;
  stmts_match_span : Stmts_match_span.t;
  cache : tout Caching.Cache.t option;
  (* TODO: this does not have to be in tout; maybe split tin in 2? *)
  config: Config_semgrep.t;
}
(*e: type [[Matching_generic.tin]] *)
(*s: type [[Matching_generic.tout]] *)
(* list of possible outcoming matching environments *)
and tout = tin list
(*e: type [[Matching_generic.tout]] *)

(*s: type [[Matching_generic.matcher]] *)
(* A matcher is something taking an element A and an element B
 * (for this module A will be the AST of the pattern and B
 * the AST of the program we want to match over), then some environment
 * information tin, and it will return something (tout) that will
 * represent a match between element A and B.
*)
(* currently 'a and 'b are usually the same type as we use the
 * same language for the host language and pattern language
*)
type ('a, 'b) matcher = 'a -> 'b -> tin -> tout
(*e: type [[Matching_generic.matcher]] *)

(* monadic combinators *)
(*s: signature [[Matching_generic.monadic_bind]] *)
val ( >>= ) : (tin -> tout) -> (unit -> tin -> tout) -> tin -> tout
(*e: signature [[Matching_generic.monadic_bind]] *)
(*s: signature [[Matching_generic.TODOOPERATOR2]] *)
val ( >||> ) : (tin -> tout) -> (tin -> tout) -> tin -> tout
(*e: signature [[Matching_generic.TODOOPERATOR2]] *)
(*s: signature [[Matching_generic.TODOOPERATOR3]] *)
val ( >!> ) : (tin -> tout) -> (unit -> tin -> tout) -> tin -> tout
(*e: signature [[Matching_generic.TODOOPERATOR3]] *)

(*s: signature [[Matching_generic.return]] *)
val return : unit -> tin -> tout
(*e: signature [[Matching_generic.return]] *)
(*s: signature [[Matching_generic.fail]] *)
val fail : unit -> tin -> tout
(*e: signature [[Matching_generic.fail]] *)

val or_list: ('a, 'b) matcher -> 'a -> 'b list -> (tin -> tout)

(* shortcut for >>=, since OCaml 4.08 you can define those "extended-let" *)
val (let*) : (tin -> tout) -> (unit -> tin -> tout) -> tin -> tout

(*s: signature [[Matching_generic.empty_environment]] *)
val empty_environment :
  tout Caching.Cache.t option -> Config_semgrep.t -> tin
(*e: signature [[Matching_generic.empty_environment]] *)

val add_mv_capture :
  Metavariable.mvar -> Metavariable.mvalue -> tin -> tin

val get_mv_capture :
  Metavariable.mvar -> tin -> Metavariable.mvalue option

(* Update the matching list of statements by providing a new matching
   statement. *)
val extend_stmts_match_span : AST_generic.stmt -> tin -> tin

(*s: signature [[Matching_generic.envf]] *)
val envf :
  (Metavariable.mvar AST_generic.wrap, Metavariable.mvalue) matcher
(*e: signature [[Matching_generic.envf]] *)

val if_config:
  (Config_semgrep.t -> bool) ->
  then_:(tin -> tout) ->
  else_: (tin -> tout) ->
  tin -> tout

(*s: signature [[Matching_generic.check_and_add_metavar_binding]] *)
val check_and_add_metavar_binding :
  Metavariable.mvar * Metavariable.mvalue ->
  tin -> tin option
(*e: signature [[Matching_generic.check_and_add_metavar_binding]] *)

(* helpers *)
(*s: signature [[Matching_generic.has_ellipsis_stmts]] *)
val has_ellipsis_stmts : AST_generic.stmt list -> bool
(*e: signature [[Matching_generic.has_ellipsis_stmts]] *)
val inits_and_rest_of_list: 'a list -> ('a list * 'a list) list
(*s: signature [[Matching_generic.all_elem_and_rest_of_list]] *)
val all_elem_and_rest_of_list : 'a list -> ('a * 'a list) list
(*e: signature [[Matching_generic.all_elem_and_rest_of_list]] *)
(*s: signature [[Matching_generic.is_regexp_string]] *)
(*e: signature [[Matching_generic.is_regexp_string]] *)
type regexp = Re.re
(*s: signature [[Matching_generic.regexp_of_regexp_string]] *)
val regexp_matcher_of_regexp_string: string -> (string -> bool)
(*e: signature [[Matching_generic.regexp_of_regexp_string]] *)

val equal_ast_binded_code :
  Metavariable.mvalue -> Metavariable.mvalue -> bool

(* generic matchers *)
(*s: signature [[Matching_generic.m_option]] *)
val m_option : ('a, 'b) matcher -> ('a option, 'b option) matcher
(*e: signature [[Matching_generic.m_option]] *)
(*s: signature [[Matching_generic.m_option_ellipsis_ok]] *)
val m_option_ellipsis_ok :
  (AST_generic.expr -> 'a -> tin -> tout) ->
  AST_generic.expr option -> 'a option -> tin -> tout
(*e: signature [[Matching_generic.m_option_ellipsis_ok]] *)
(*s: signature [[Matching_generic.m_option_none_can_match_some]] *)
val m_option_none_can_match_some :
  ('a -> 'b -> tin -> tout) -> 'a option -> 'b option -> tin -> tout
(*e: signature [[Matching_generic.m_option_none_can_match_some]] *)

(*s: signature [[Matching_generic.m_ref]] *)
val m_ref : ('a, 'b) matcher -> ('a ref, 'b ref) matcher
(*e: signature [[Matching_generic.m_ref]] *)

(*s: signature [[Matching_generic.m_list]] *)
val m_list : ('a, 'b) matcher -> ('a list,'b list) matcher
(*e: signature [[Matching_generic.m_list]] *)
(*s: signature [[Matching_generic.m_list_prefix]] *)
val m_list_prefix : ('a, 'b) matcher -> ('a list,'b list) matcher
(*e: signature [[Matching_generic.m_list_prefix]] *)
(*s: signature [[Matching_generic.m_list_with_dots]] *)
val m_list_with_dots :
  ('a,'b) matcher -> ('a -> bool) -> bool -> ('a list, 'b list) matcher
(*e: signature [[Matching_generic.m_list_with_dots]] *)
val m_list_in_any_order:
  less_is_ok:bool -> ('a,'b) matcher -> ('a list, 'b list) matcher

(* use = *)
val m_eq : ('a, 'a) matcher
(*s: signature [[Matching_generic.m_bool]] *)
val m_bool : (bool, bool) matcher
(*e: signature [[Matching_generic.m_bool]] *)
(*s: signature [[Matching_generic.m_int]] *)
val m_int : (int, int) matcher
(*e: signature [[Matching_generic.m_int]] *)
(*s: signature [[Matching_generic.m_string]] *)
val m_string : (string, string) matcher
(*e: signature [[Matching_generic.m_string]] *)
(*s: signature [[Matching_generic.string_is_prefix]] *)
val string_is_prefix : string -> string -> bool
(*e: signature [[Matching_generic.string_is_prefix]] *)
(*s: signature [[Matching_generic.m_string_prefix]] *)
val m_string_prefix : string -> string -> tin -> tout
(*e: signature [[Matching_generic.m_string_prefix]] *)
val m_string_ellipsis_or_regexp_or_default:
  ?use_m_string_prefix_for_default:bool ->
  string -> string -> tin -> tout

(*s: signature [[Matching_generic.m_info]] *)
val m_info : 'a -> 'b -> tin -> tout
(*e: signature [[Matching_generic.m_info]] *)
(*s: signature [[Matching_generic.m_tok]] *)
val m_tok : 'a -> 'b -> tin -> tout
(*e: signature [[Matching_generic.m_tok]] *)
(*s: signature [[Matching_generic.m_wrap]] *)
val m_wrap : ('a -> 'b -> tin -> tout) -> 'a * 'c -> 'b * 'd -> tin -> tout
(*e: signature [[Matching_generic.m_wrap]] *)
(*s: signature [[Matching_generic.m_bracket]] *)
val m_bracket :
  ('a -> 'b -> tin -> tout) -> 'c * 'a * 'd -> 'e * 'b * 'f -> tin -> tout
(*e: signature [[Matching_generic.m_bracket]] *)
val m_tuple3 :
  ('a -> 'b -> tin -> tout) -> ('c -> 'd -> tin -> tout) -> ('e -> 'f -> tin -> tout) ->
  'a * 'c * 'e -> 'b * 'd * 'f -> tin -> tout

(*s: signature [[Matching_generic.m_other_xxx]] *)
val m_other_xxx : 'a -> 'a -> tin -> tout
(*e: signature [[Matching_generic.m_other_xxx]] *)
(*e: semgrep/matching/Matching_generic.mli *)
