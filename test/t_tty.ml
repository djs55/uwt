open Uwt.Tty
open OUnit2

let l = [
  ("set_mode/reset_mode">::
   fun _ctx ->
     let is_tty = Uwt_base.Misc.guess_handle Unix.stdin = Uwt_base.Misc.Tty in
     skip_if (not is_tty) "stdin no tty";
     let t = init_exn ~read:true Uwt.stdin in
     assert_equal () (set_mode_exn t ~mode:Raw);
     assert_equal () (reset_mode_exn ()));
  ("winsize">::
   fun _ctx ->
     let is_tty = Uwt_base.Misc.guess_handle Unix.stdout = Uwt_base.Misc.Tty in
     skip_if (not is_tty) "stdout no tty";
     let t = init_exn ~read:true Uwt.stdout in
     let s = get_winsize_exn t in
     assert_equal true (s.width > 0 && s.height > 0));
]

let l = "TTy">:::l
