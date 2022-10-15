#ifndef _SRC__ASM__LIBC_DEFS__LIBC_AVX512_VECS_H_
#define _SRC__ASM__LIBC_DEFS__LIBC_AVX512_VECS_H_


#ifdef HAS_VEC
#error "Multiple VEC configs included!"
#endif

#define HAS_VEC 1
#include "libc-vec-macros.h"

#define USE_WITH_EVEX512 1
#define SECTION(p)       p##.evex512

#define VEC_SIZE 64
/* 6-byte mov instructions with EVEX.  */
#define MOV_SIZE 6
/* No vzeroupper needed.  */
#define RET_SIZE 1
#define VZEROUPPER

#define VMOVU  vmovdqu64
#define VMOVA  vmovdqa64
#define VMOVNT vmovntdq

/* Often need to access xmm/ymm portion.  */
#define VEC_xmm VEC_hi_xmm
#define VEC_ymm VEC_hi_ymm
#define VEC     VEC_hi_zmm

#define VEC_lo VEC_any_zmm


#endif
