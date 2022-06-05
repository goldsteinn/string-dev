#ifndef _SRC__ASM__LIBC_DEFS__LIBC_AVX2_VECS_H_
#define _SRC__ASM__LIBC_DEFS__LIBC_AVX2_VECS_H_


#define USE_WITH_AVX2 1
/* Included by RTM version.  */
#ifndef SECTION
#define SECTION(p) p##.avx
#endif
#include "libc-avx-vecs.h"

#endif
