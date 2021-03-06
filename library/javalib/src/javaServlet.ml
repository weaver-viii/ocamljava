(*
 * This file is part of OCaml-Java library.
 * Copyright (C) 2007-2015 Xavier Clerc.
 *
 * OCaml-Java library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * OCaml-Java library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)


(* Generic servlets *)

type generic = javax'servlet'GenericServlet java_instance

type request = javax'servlet'ServletRequest java_instance

type response = javax'servlet'ServletResponse java_instance

module type Generic = sig
  type t
  val init    : generic -> t
  val service : t -> generic -> request -> response -> unit
  val destroy : t -> generic -> unit
end

module Default_Generic = struct
  let service _ _ _ _ = ()
  let destroy _ _     = ()
end


(* HTTP servlets *)

open Class'javax'servlet'http'HttpServlet
open Class'javax'servlet'http'HttpServletRequest
open Class'javax'servlet'http'HttpServletResponse

type http = _'HttpServlet java_instance

type http_request = _'HttpServletRequest java_instance

type http_response = _'HttpServletResponse java_instance

module type HTTP = sig
  type t
  val init              : http -> t
  val do_delete         : t -> http -> http_request -> http_response -> unit
  val do_get            : t -> http -> http_request -> http_response -> unit
  val do_head           : t -> http -> http_request -> http_response -> unit
  val do_options        : t -> http -> http_request -> http_response -> unit
  val do_post           : t -> http -> http_request -> http_response -> unit
  val do_put            : t -> http -> http_request -> http_response -> unit
  val do_trace          : t -> http -> http_request -> http_response -> unit
  val get_last_modified : t -> http -> http_request -> java_long
  val destroy           : t -> http -> unit
end

let string_of_option = function
  | `GET     -> !@"GET"
  | `HEAD    -> !@"HEAD"
  | `POST    -> !@"POST"
  | `PUT     -> !@"PUT"
  | `DELETE  -> !@"DELETE"
  | `TRACE   -> !@"TRACE"
  | `OPTIONS -> !@"OPTIONS"

let options resp l =
  Java.call "HttpServletResponse.setHeader(String,String)"
    resp
    !@"Allow"
    (match l with
    | hd :: tl ->
        List.fold_left
          (fun acc opt ->
            acc
            |> JavaStringBuilder.append_string |. !@", "
            |> JavaStringBuilder.append_string |. (string_of_option opt))
          (JavaStringBuilder.make_of_string (string_of_option hd))
          tl
        |> JavaStringBuilder.to_string
    | [] ->
        !@"")

module Default_HTTP = struct
  let error meth req resp =
    let protocol = Java.call "HttpServletRequest.getProtocol()" req in
    let code =
      if Java.call "String.endsWith(String)" protocol !@"1.1" then
        Java.get "HttpServletResponse.SC_METHOD_NOT_ALLOWED" ()
      else
        Java.get "HttpServletResponse.SC_BAD_REQUEST" () in
    Printf.sprintf "HTTP method %s is not supported by this URL" meth
    |> JavaString.of_string
    |> Java.call "HttpServletResponse.sendError(int,String)" resp code
  let do_delete _ _ req resp = error "delete" req resp
  let do_get    _ _ req resp = error "get"    req resp
  let do_head   _ _ req resp = error "head"   req resp
  let do_post   _ _ req resp = error "post"   req resp
  let do_put    _ _ req resp = error "put"    req resp
  let do_trace _ _ req resp =
    let buff = 
      JavaStringBuilder.(make_of_string !@"TRACE "
      |> append_string |. (Java.call "HttpServletRequest.getRequestURI()" req)
      |> append_string |. !@" "
      |> append_string |.(Java.call "HttpServletRequest.getProtocol()" req)) in
    let headers = Java.call "HttpServletRequest.getHeaderNames()" req in
    while Java.call "java.util.Enumeration.hasMoreElements()" headers do
      let header_name =
        Java.call "java.util.Enumeration.nextElement()" headers
        |> Java.cast "String" in
      let header_value =
        Java.call "HttpServletRequest.getHeader(String)"
          req header_name in
      JavaStringBuilder.(buff
      |> append_string |. !@"\r\n"
      |> append_string |. header_name
      |> append_string |. !@": "
      |> append_string |. header_value
      |> ignore)
    done;
    ignore (JavaStringBuilder.append_string buff !@"\r\n");
    let length = Java.call "StringBuilder.length()" buff in
    Java.call "HttpServletResponse.setContentType(String)" resp !@"message/http";
    Java.call "HttpServletResponse.setContentLength(int)" resp length;
    let out = Java.call "HttpServletResponse.getOutputStream()" resp in
    buff
    |> JavaStringBuilder.to_string
    |> Java.call "javax.servlet.ServletOutputStream.print(String)" out;
    Java.call "java.io.OutputStream.close()" out
  let get_last_modified _ _ _ = -1L
  let destroy _ _ = ()
end


(* Filters *)

type filter_config = javax'servlet'FilterConfig java_instance

type filter_chain = javax'servlet'FilterChain java_instance

let do_filter chain req resp =
  Java.call "javax.servlet.FilterChain.doFilter(javax.servlet.ServletRequest,javax.servlet.ServletResponse)"
    chain req resp

module type Filter = sig
  val init : filter_config -> unit
  val do_filter : request -> response -> filter_chain -> unit
  val destroy : unit -> unit
end


(* Listeners *)

type servlet_context_event = javax'servlet'ServletContextEvent java_instance

type servlet_context_attribute_event = javax'servlet'ServletContextAttributeEvent java_instance

type http_session_event = javax'servlet'http'HttpSessionEvent java_instance

type http_session_binding_event = javax'servlet'http'HttpSessionBindingEvent java_instance

module type ServletContextListener = sig
  val context_initialized : servlet_context_event -> unit
  val context_destroyed   : servlet_context_event -> unit
end

module type ServletContextAttributeListener = sig
  val attribute_added    : servlet_context_attribute_event -> unit
  val attribute_removed  : servlet_context_attribute_event -> unit
  val attribute_replaced : servlet_context_attribute_event -> unit
end

module type HTTPSessionListener = sig
  val session_created   : http_session_event -> unit
  val session_destroyed : http_session_event -> unit
end

module type HTTPSessionActivationListener = sig
  val session_did_activate   : http_session_event -> unit
  val session_will_passivate : http_session_event -> unit
end

module type HTTPSessionAttributeListener = sig
  val attribute_added    : http_session_binding_event -> unit
  val attribute_removed  : http_session_binding_event -> unit
  val attribute_replaced : http_session_binding_event -> unit
end

module type HTTPSessionBindingListener = sig
  val value_bound   : http_session_binding_event -> unit
  val value_unbound : http_session_binding_event -> unit
end

module type HTTPSessionIdListener = sig
  val session_id_changed : http_session_event -> JavaString.t -> unit
end
