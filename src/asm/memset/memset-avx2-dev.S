#define USE_AS_AVX2	1

#define MEMSET_SET_VEC0_AND_SET_RETURN(d, r)	\
	vmovd	d, %xmm0;	\
	movq	r, %rax;

#define WMEMSET_SET_VEC0_AND_SET_RETURN(d, r)	\
	MEMSET_SET_VEC0_AND_SET_RETURN (d, r)

#define MEMSET_VDUP_TO_VEC0_HIGH()	vpbroadcastb %xmm0, %ymm0
#define MEMSET_VDUP_TO_VEC0_LOW()	vpbroadcastb %xmm0, %xmm0

#define WMEMSET_VDUP_TO_VEC0_HIGH()	vpbroadcastd %xmm0, %ymm0
#define WMEMSET_VDUP_TO_VEC0_LOW()	vpbroadcastd %xmm0, %xmm0

#define WMEMSET0	wmemset_avx2_dev
#define MEMSET0	memset_avx2_dev
#define MEMSET1	memset_avx2_erms_dev


#define USE_XMM_LESS_VEC
#include "core/memset-vec-dev.S"
