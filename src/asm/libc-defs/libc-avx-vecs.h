#ifndef _SRC__ASM__LIBC_DEFS__LIBC_AVX_VECS_H_
#define _SRC__ASM__LIBC_DEFS__LIBC_AVX_VECS_H_


#ifdef HAS_VEC
#error "Multiple VEC configs included!"
#endif

#define HAS_VEC 1
#include "libc-vec-macros.h"

#ifndef USE_WITH_AVX2
#define USE_WITH_AVX 1
#endif
/* Included by RTM version.  */
#ifndef SECTION
#define SECTION(p) p##.avx
#endif

#define VEC_SIZE 32
/* 4-byte mov instructions with AVX2.  */
#define MOV_SIZE 4
/* 1 (ret) + 3 (vzeroupper).  */
#define RET_SIZE   4
#define VZEROUPPER vzeroupper

#define VMOVU  vmovdqu
#define VMOVA  vmovdqa
#define VMOVNT vmovntdq

/* Often need to access xmm portion.  */
#define VEC_xmm VEC_any_xmm
#define VEC     VEC_any_ymm

#endif
