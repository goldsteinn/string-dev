#ifndef _SRC__ASM__LIBC_DEFS__LIBC_SSE2_VECS_H_
#define _SRC__ASM__LIBC_DEFS__LIBC_SSE2_VECS_H_


#ifdef HAS_VEC
#error "Multiple VEC configs included!"
#endif

#define HAS_VEC 1
#include "libc-vec-macros.h"

#define USE_WITH_SSE2 1
#define SECTION(p)    p

#define VEC_SIZE 16
/* 3-byte mov instructions with SSE2.  */
#define MOV_SIZE 3
/* No vzeroupper needed.  */
#define RET_SIZE 1

#define VMOVU  movups
#define VMOVA  movaps
#define VMOVNT movntdq
#define VZEROUPPER

#define VEC_xmm VEC_any_xmm
#define VEC     VEC_any_xmm


#endif
