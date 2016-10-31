/* Libuv bindings for OCaml
 * http://github.com/fdopen/uwt
 * Copyright (C) 2015-2016 Andreas Hauptmann
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, with linking exceptions;
 * either version 2.1 of the License, or (at your option) any later
 * version. See COPYING file for details.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 */

#ifndef __UWT_STUBS_HANDLE_H
#define __UWT_STUBS_HANDLE_H

#include "uwt_stubs_base.h"

#ifdef __cplusplus
extern "C" {
#endif

UWT_EXTERN2(uwt_close_wait);
UWT_EXTERN1(uwt_close_nowait);
UWT_EXTERN1(uwt_is_active_na);
UWT_EXTERN1(uwt_ref_na);
UWT_EXTERN1(uwt_unref_na);
UWT_EXTERN1(uwt_has_ref_na);
UWT_EXTERN1(uwt_fileno);

/* handle_ext */
UWT_EXTERN2(uwt_get_buffer_size_common_na);
UWT_EXTERN3(uwt_set_buffer_size_common_na);

/* functions used by several subtypes of uv_handle_t */
UWT_LOCAL void
uwt__alloc_cb(uv_handle_t*, size_t suggested_size, uv_buf_t*);

UWT_LOCAL void
uwt__alloc_own_cb(uv_handle_t*, size_t suggested_size, uv_buf_t*);

UWT_LOCAL void
uwt__pipe_tcp_connect_cb(uv_connect_t*, int);

#define UV_HANDLE_BOOL(type,fun,uninit_ok)                  \
  CAMLprim value                                            \
  uwt_ ## fun ## _na(value o_stream)                        \
  {                                                         \
    value ret = Val_long(0);                                \
    struct handle * s = Handle_val(o_stream);               \
    if ( s && s->handle && (uninit_ok || s->initialized )){ \
      type* stream = (type*)s->handle;                      \
      if ( uv_ ## fun(stream) ){                            \
        ret = Val_long(1);                                  \
      }                                                     \
    }                                                       \
    return ret;                                             \
  }

#define UV_HANDLE_VOID(name)                        \
  CAMLprim value                                    \
  uwt_ ## name ## _na(value o_stream)               \
  {                                                 \
    struct handle * s = Handle_val(o_stream);       \
    if ( s && s->handle && s->close_called == 0 ){  \
      uv_ ## name (s->handle);                      \
    }                                               \
    return Val_unit;                                \
  }

#define HANDLE_CB_INIT(x)                             \
  struct handle *h_ = NULL;                           \
  do {                                                \
    uv_handle_t *x_ = (uv_handle_t*)(x);              \
    if (unlikely( !x_ || (h_ = x_->data) == NULL )){  \
      DEBUG_PF("data lost");                          \
      return;                                         \
    }                                                 \
    if (unlikely( h_->close_called )){                \
      DEBUG_PF("callback called after close!");       \
      return;                                         \
    }                                                 \
    ++h_->in_callback_cnt;                            \
    GET_RUNTIME();                                    \
  } while (0)

#define HANDLE_CB_INIT_WITH_CLEAN(x)                  \
  struct handle *h_ = NULL;                           \
  do {                                                \
    uv_handle_t *x_ = (uv_handle_t*)(x);              \
    if (unlikely( !x_ || (h_ = x_->data) == NULL )){  \
      DEBUG_PF("data lost");                          \
      return;                                         \
    }                                                 \
    ++h_->in_callback_cnt;                            \
    GET_RUNTIME();                                    \
  } while (0)


#define CLOSE_HANDLE_IF_UNREFERENCED(s)         \
  do {                                          \
    struct handle * h__  = s;                   \
    if (unlikely( h__->in_use_cnt == 0 &&       \
                  h__->in_callback_cnt == 0 &&  \
                  h__->finalize_called == 1 &&  \
                  h__->close_called == 0 )){    \
      uwt__handle_finalize_close(h__);          \
    }                                           \
  } while (0)

#define HANDLE_CB_RET(val)                      \
  do {                                          \
    value v_ = (val);                           \
    if (unlikely( Is_exception_result(v_) )){   \
      uwt__add_exception(h_->loop,v_);          \
    }                                           \
    --h_->in_callback_cnt;                      \
    CLOSE_HANDLE_IF_UNREFERENCED(h_);           \
  } while (0)

#define HANDLE_IS_INVALID(_xs)                            \
  (unlikely( !_xs || !_xs->handle || _xs->close_called ))

#define HANDLE_IS_INVALID_UNINIT(_xs)                     \
  (unlikely( !_xs || !_xs->handle || _xs->close_called || \
             _xs->initialized == 0 ))

#define HANDLE_NINIT_END GR_ROOT_ENLARGE

#define HANDLE_NCHECK(_xs)                      \
  do {                                          \
    if ( HANDLE_IS_INVALID(_xs) ){              \
      return VAL_UWT_INT_RESULT_EBADF;          \
    }                                           \
  } while (0)

#define HANDLE_NO_UNINIT_CLOSED_INT_RESULT(xs)  \
  do {                                          \
    struct handle * p_ = Handle_val(xs);        \
    if ( HANDLE_IS_INVALID_UNINIT(p_) ){        \
      return VAL_UWT_INT_RESULT_EBADF;          \
    }                                           \
  } while (0)

#define HANDLE_NO_UNINIT_CLOSED_WRAP(xs)          \
  do {                                            \
    struct handle * p_ = Handle_val(xs);          \
    if ( HANDLE_IS_INVALID_UNINIT(p_) ){          \
      value ret = caml_alloc_small(1,Error_tag);  \
      Field(ret,0) = VAL_UWT_ERROR_EBADF;         \
      return ret;                                 \
    }                                             \
  } while (0)

#define HANDLE_NO_UNINIT_NA(_xs)                \
  do {                                          \
    if (unlikely( _xs->initialized == 0 )){     \
      return VAL_UWT_INT_RESULT_EBADF;          \
    }                                           \
  } while (0)


#define HANDLE_INIT2(s,o_s,c)                   \
  struct handle * s = Handle_val(o_s);          \
  HANDLE_NCHECK(s);                             \
  CAMLparam2(o_s,c);                            \
  HANDLE_NINIT_END()

#define HANDLE_INIT3(s,o_s,c,d)                 \
  struct handle * s = Handle_val(o_s);          \
  HANDLE_NCHECK(s);                             \
  CAMLparam3(o_s,c,d);                          \
  HANDLE_NINIT_END()

#define HANDLE_INIT4(s,o_s,c,d,e)               \
  struct handle * s = Handle_val(o_s);          \
  HANDLE_NCHECK(s);                             \
  CAMLparam4(o_s,c,d,e);                        \
  HANDLE_NINIT_END()

#define HANDLE2_INIT(s1,o_s1,s2,o_s2,x,y)       \
  struct handle * s1 = Handle_val(o_s1);        \
  struct handle * s2 = Handle_val(o_s2);        \
  HANDLE_NCHECK(s1);                            \
  HANDLE_NCHECK(s2);                            \
  CAMLparam4(o_s1,o_s2,x,y);                    \
  HANDLE_NINIT_END()

#define HANDLE_INIT(s,o_s)                      \
  struct handle * s = Handle_val(o_s);          \
  HANDLE_NCHECK(s);                             \
  CAMLparam1(o_s);                              \
  HANDLE_NINIT_END()

#define HANDLE_NINIT_NA(s,o_s)                  \
  struct handle * s = Handle_val(o_s);          \
  HANDLE_NCHECK(s)

#ifdef __cplusplus
}
#endif

#endif /* __UWT_STUBS_HANDLE_H */
