#define USE_AS_SSE2	1

#define MOV_SIZE	3
#define RET_SIZE	1

#define VEC(i)	xmm##i
#define VMOVU	movups
#define VMOVA	movaps

# define MEMSET_SET_VEC0_AND_SET_RETURN(d, r) \
  movd d, %xmm0; \
  movq r, %rax; \
  punpcklbw %xmm0, %xmm0; \
  punpcklwd %xmm0, %xmm0; \
  pshufd $0, %xmm0, %xmm0

# define WMEMSET_SET_VEC0_AND_SET_RETURN(d, r) \
  movd d, %xmm0; \
  pshufd $0, %xmm0, %xmm0; \
  movq r, %rax

# define MEMSET_VDUP_TO_VEC0_HIGH()
# define MEMSET_VDUP_TO_VEC0_LOW()

# define WMEMSET_VDUP_TO_VEC0_HIGH()
# define WMEMSET_VDUP_TO_VEC0_LOW()



#define WMEMSET0	wmemset_sse2_glibc
#define MEMSET0	memset_sse2_glibc
#define MEMSET1	memset_sse2_erms_glibc

#include "core/memset-vec-glibc.S"
