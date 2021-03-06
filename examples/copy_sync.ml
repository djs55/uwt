let try_finally f x finallly' y =
  let res =
    try f x with exn -> finallly' y; raise exn in
  finallly' y;
  res

module US = Uv_fs_sync
module UF = Uwt_base.Fs_types

let rexn s = function
| Ok x -> x
| Error r ->
  Printf.eprintf "%s %s:%s\n%!" s (Uwt_base.err_name r) (Uwt_base.strerror r);
  raise Exit

let copy ~src ~dst =
  let fdi = US.openfile ~mode:[UF.O_RDONLY] src |> rexn ("open " ^ src) in
  try_finally ( fun fdi ->
      let fdo =
        US.openfile ~mode:[UF.O_WRONLY ; UF.O_CREAT ; UF.O_TRUNC] dst |>
        rexn ("open " ^ dst)
      in
      try_finally ( fun fdo ->
          let b_len = 128 in
          let buf = Bytes.create b_len in
          let rec read () =
            let len = US.read fdi ~buf ~pos:0 ~len:b_len |> rexn "read" in
            if len = 0 then ()
            else write ~offset:0 ~len
          and write ~offset ~len =
            let n = US.write fdo ~buf ~pos:offset ~len |> rexn "write" in
            let len' = len - n in
            if len' <= 0 then
              read ()
            else
              write ~offset:(offset+n) ~len:len'
          in
          read ()
        ) fdo ( fun fdo -> US.close fdo |> rexn ("close " ^ dst) ) fdo
    )
    fdi ( fun fdi -> US.close fdi |> rexn ("close " ^ src) ) fdi

let copy_ba ~src ~dst =
  let fdi = US.openfile ~mode:[UF.O_RDONLY] src |> rexn ("open " ^ src) in
  try_finally ( fun fdi ->
      let fdo =
        US.openfile ~mode:[UF.O_WRONLY ; UF.O_CREAT ; UF.O_TRUNC] dst |>
        rexn ("open " ^ dst)
      in
      try_finally ( fun fdo ->
          let b_len = 65_536 in
          let buf = Uwt_bytes.create b_len in
          let rec read () =
            let len = US.read_ba fdi ~buf ~pos:0 ~len:b_len |> rexn "read_ba" in
            if len = 0 then ()
            else write ~offset:0 ~len
          and write ~offset ~len =
            let n = US.write_ba fdo ~buf ~pos:offset ~len |> rexn "write_ba" in
            let len' = len - n in
            if len' <= 0 then
              read ()
            else
              write ~offset:(offset+n) ~len:len'
          in
          read ()
        ) fdo ( fun fdo -> US.close fdo |> rexn ("close " ^ dst) ) fdo
    )
    fdi ( fun fdi -> US.close fdi |> rexn ("close " ^ src) ) fdi

let copy_sendfile ~src ~dst =
  let fdi = US.openfile ~mode:[UF.O_RDONLY] src |> rexn ("open " ^ src) in
  try_finally ( fun fdi ->
      let fdo =
        US.openfile ~mode:[UF.O_WRONLY ; UF.O_CREAT ; UF.O_TRUNC] dst |>
        rexn ("open " ^ dst)
      in
      try_finally ( fun fdo ->
          let total_length = US.(((fstat fdi) |> rexn "fstat").st_size) in
          let rec iter pos =
            if Int64.sub total_length pos <= Int64.zero then () else
            let i = US.sendfile ~pos ~dst:fdo ~src:fdi ()
                    |> rexn "sendfile" in
            iter @@ Int64.add pos @@ Int64.of_nativeint i
          in
          iter Int64.zero
        ) fdo (fun fdo -> US.close fdo |> rexn ("close " ^ dst)) fdo
    )
    fdi ( fun fdi -> US.close fdi |> rexn ("close " ^ src) ) fdi

let () =
  let files = ref []
  and use_ba = ref false
  and use_sendfile = ref false in
  let speclist = [
    ("-b", Arg.Set use_ba, ": use bigarray as buffer");
    ("-s", Arg.Set use_sendfile, ": use sendfile") ]
  and usage = Sys.executable_name ^ " -o file1 file2"
  and anonf x = files:= x :: !files in
  Arg.parse speclist anonf usage;
  match List.rev !files with
  | src::dst::[] ->
    if !use_ba then
      copy_ba ~src ~dst
    else if !use_sendfile then
      copy_sendfile ~src ~dst
    else
      copy ~src ~dst
  | _ ->
    prerr_endline usage;
    exit 1
