open Lwt.Infix
open Capnp_rpc_lwt

let ( >>!= ) = Lwt_result.bind

type t = [ `Process_97c386322a4cc46c ] Hoke__Raw.MessageWrapper.Capability.t

let or_fail = function
  | Ok v -> v
  | Error (`Capnp e) -> Fmt.failwith "%a" Capnp_rpc.Error.pp e

let local ~stdin ~stdout ~stderr =
  let module X = Raw.Service.Process in
  X.local
  @@ object
       inherit X.service

       method stdout_impl params release_param_caps =
         let open X.Stdout in
         let data = Params.data_get params in
         release_param_caps ();
         Lwt.async (fun () -> stdout data);
         Service.return_empty ()

       method stderr_impl params release_param_caps =
         let open X.Stderr in
         let data = Params.data_get params in
         release_param_caps ();
         Lwt.async (fun () -> stderr data);
         Service.return_empty ()

       method stdin_impl _ release_param_caps =
         let open X.Stdin in
         release_param_caps ();
         Service.return_lwt @@ fun () ->
         stdin () >|= fun s ->
         let response, results = Service.Response.create Results.init_pointer in
         Results.data_set results s;
         Ok response
     end

module X = Raw.Client.Process

let stdout t ~data =
  let open X.Stdout in
  let request, params = Capability.Request.create Params.init_pointer in
  Params.data_set params data;
  Capability.call_for_unit t method_id request >|= or_fail

let stderr t ~data =
  let open X.Stderr in
  let request, params = Capability.Request.create Params.init_pointer in
  Params.data_set params data;
  Capability.call_for_unit t method_id request >|= or_fail

let stdin t =
  let open X.Stdin in
  let request = Capability.Request.create_no_args () in
  Capability.call_for_value t method_id request >|= or_fail >|= fun result ->
  Results.data_get result
