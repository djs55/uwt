open Common
open OUnit2
open Uwt_base.Misc
(* Worthwile tests are not possible in most cases, because the
   functions are not implemented completely on all systems - and I
   don't know anything about the target system :) So I just access at
   least any generated value in each case, so I know, the c-stubs
   don't return garbage *)
let l = [
  ("resident_set_memory">:: fun _ ->
      assert_equal true (resident_set_memory_exn () > 64L ));
  ("uptime">:: fun _ -> assert_equal true (uptime_exn () > 20. ));
  ("getrusage">:: fun _ ->
      let x = getrusage_exn () |> D.show_rusage |> String.length in
      assert_equal true ( x > 3 ));
  ("cpu_info">:: fun _ ->
      let x = cpu_info_exn () |> Array.map D.show_cpu_info |>
              Array.to_list |> String.concat "\n" |> String.length
      in
      assert_equal true ( x > 30 ));
  ("interface_addresses">:: fun _ ->
      let x = interface_addresses_exn () |>
              Array.map D.show_interface_address |> Array.to_list |>
              String.concat "\n" |> String.length in
      assert_equal true ( x > 30 ));
  ("load_avg">:: fun _ ->
      let (x,y,z) = load_avg () in
      let t = match Sys.win32 with
      | true -> x >= 0. && y >= 0. && z >= 0.
      | false -> x >= 0. && y > 0. && z > 0.
      in
      assert_equal true t);
  ("ip4_addr">:: fun _ ->
      let ip4 = "127.0.2.1" in
      let ip4' = ip4_addr_exn ip4 99 |> ip4_name_exn in
      assert_equal ip4 ip4');
  ("ip6_addr">:: fun _ ->
      let ip6 = "2231:1fa8:45a3:3121:1333:8a2e:237a:733a" in
      let ip6' = ip6_addr_exn ip6 2199 |> ip6_name_exn in
      assert_equal ip6 ip6');
  ("ip46_addr_unix">:: fun _ ->
      (* Unix.inet_addr is abstract, use polymorphic comparison to
         ensure that they are still represented as strings *)
      let ip1 = Unix.inet_addr_of_string "127.0.0.1" in
      let port = 80 in
      let ip2 = match Uwt_base.Misc.ip4_addr_exn "127.0.0.1" port with
      | Unix.ADDR_INET(x,p) when p = port -> x
      | Unix.ADDR_INET _  | Unix.ADDR_UNIX _ -> assert false in
      assert_equal ip1 ip2;
      assert_equal Unix.inet_addr_loopback ip2;
      let s = "2001:db8:85a3:8d3:1319:8a2e:370:7348" in
      let ip1 = Unix.inet_addr_of_string s in
      let ip2 = match Uwt_base.Misc.ip6_addr_exn s port with
      | Unix.ADDR_INET(x,p) when p = port -> x
      | Unix.ADDR_INET _  | Unix.ADDR_UNIX _ -> assert false in
      assert_equal ip1 ip2);
  ("get_total_memory">:: fun _ ->
      let p = get_total_memory () > 134217728L in
      assert_equal true p );
  ("hrtime">:: fun _ ->
      let p = hrtime () > 128L in
      assert_equal true p );
  ("version">:: fun _ ->
      let {major;minor;patch} = version () in
      let p = major + minor + patch >= 1 in
      assert_equal true p );
  ("version_string">:: fun _ ->
      let p = version_string () |> String.length > 3 in
      assert_equal true p );
  ("os_homedir">:: fun _ ->
      let open Uwt in
      let p = match os_homedir () with
      | Ok "" -> false
      | Error ENOSYS ->
        let {major;minor;_} = version () in
        if major > 1 || minor >= 6 then
          false
        else
          true
      | Ok _ -> true
      | Error _ -> false
      in
      assert_equal true p);
  ("os_tmpdir">:: fun _ ->
      let open Uwt in
      let p = match os_tmpdir () with
      | Ok "" -> false
      | Error ENOSYS ->
        let {major;minor;_} = version () in
        if major > 1 || minor >= 9 then
          false
        else
          true
      | Ok _ -> true
      | Error _ -> false
      in
      assert_equal true p);
  ("get_passwd">:: fun _ ->
      let p = match get_passwd () with
      | Error Uwt.UNKNOWN when Sys.win32 ->
        (* TODO: get_passwd doesn't work, when user is logged in
           via cygwin's ssh. Find out why and propose a fix
           upstream *)
        true
      | Error Uwt.ENOSYS ->
        let {major;minor;_} = version () in
        if major > 1 || minor >= 9 then false else true
      | Error _ -> false
      | Ok x ->
        let open Unix in
        match Sys.win32 with
        | true ->
          x.pw_name <> "" &&
          x.pw_dir <> "" &&
          Sys.is_directory x.pw_dir
        | false ->
          let x2 = Unix.getuid () |> Unix.getpwuid in
          x.pw_name = x2.pw_name &&
          x.pw_dir = x2.pw_dir &&
          x.pw_uid = x2.pw_uid &&
          x.pw_gid = x2.pw_gid &&
          x.pw_shell = x2.pw_shell
      in
      assert_equal true p );
  ("exepath">:: fun ctx ->
      (* doesn't work very well on various *nixes *)
      let do_skip = Uwt.Sys_info.(os <> Windows && os <> Linux) in
      skip_if_not_all ctx do_skip "exepath resolution differs";
      match exepath () with
      | Error x ->
        Uwt.err_name x |>
        Printf.sprintf "expath error:%s\n" |>
        failwith
      | Ok x ->
        let x1 = Filename.is_relative x
        and x2 = Filename.is_relative Sys.executable_name in
        skip_if_not_all ctx (x1 <> x2) "exepath not tracked";
        skip_if_not_all ctx (x = Sys.executable_name ^ ".run")
          "bytecode doesn't handle symlinks";
        assert_equal Sys.executable_name x );
  ("win_version">:: fun _ ->
      let v = Uwt_base.Sys_info.win_version () in
      if not Sys.win32 then
        assert_equal v (Error Uwt.ENOSYS)
      else
        match v with
        | Error s ->
          let s = Uwt_base.err_name s in
          let msg = Printf.sprintf "win_version:%s" s in
          failwith msg
        | Ok x ->
          let slen = D.show_win_version x |> String.length in
          let open Uwt_base.Sys_info in
          assert_equal true ( slen > 30 && x.major_version >= 5 ));
  ("cwd">:: fun _ -> assert_equal (Ok (Sys.getcwd ())) (cwd ()));
  ("process_title">:: fun ctx ->
      is_contingent ctx;
      let pt = "uwt test" in
      let p = set_process_title pt in
      assert_equal (p :> int) 0;
      let pt' = get_process_title () in
      assert_equal (Ok pt) pt' );
  ("chdir">:: fun _ ->
      let o_dir = match cwd () with
      | Error _ -> assert false
      | Ok x -> x in
      let tdir = match os_tmpdir () with
      | Ok x -> x
      | Error _ -> Filename.get_temp_dir_name () in
      let tdir = match Uv_fs_sync.realpath tdir with
      | Ok y -> y
      | Error _ -> tdir in
      nm_try_finally ( fun tdir ->
          let t = Uwt_base.Misc.chdir tdir in
          assert_equal 0 (t :> int);
          let tdir' = Uwt_base.Misc.cwd () in
          assert_equal (Ok tdir) (tdir')
        ) tdir ( fun o_dir ->
          let e = Uwt_base.Misc.chdir o_dir in
          if Uwt_base.Int_result.is_error e then
            Uwt_base.Int_result.raise_exn ~name:"chdir" ~param:tdir e;
        ) o_dir );
  ("guess_handle">::fun ctx ->
      if Unix.isatty Unix.stdin then
        assert_equal Tty (guess_handle Unix.stdin);
      let f typ o1 o2 =
        let c = Unix.socket o1 o2 0 in
        assert_equal typ (guess_handle c);
        Unix.close c
      in
      f Tcp Unix.PF_INET Unix.SOCK_STREAM;
      f Udp Unix.PF_INET Unix.SOCK_DGRAM;
      if Sys.win32 = false then (
        try
          f Unknown Unix.PF_UNIX Unix.SOCK_RAW
        with (* unsupoorted on many OSes ;) *)
        | Unix.Unix_error(_,"socket",_) -> ());
      let a,b = Unix.pipe () in
      assert_equal Pipe (guess_handle a);
      assert_equal Pipe (guess_handle b);
      Unix.close a;
      Unix.close b;
      ip6_only ctx;
      f Tcp Unix.PF_INET6 Unix.SOCK_STREAM;
      f Udp Unix.PF_INET6 Unix.SOCK_DGRAM )
]

let l = "Misc">:::l
