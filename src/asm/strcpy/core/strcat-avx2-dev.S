/* strcat with AVX2
   Copyright (C) 2011-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#include "../../libc-asm-common.h"
#if IS_IN (libc)


# ifndef STRCAT
#  define STRCAT	__strcat_avx2
# endif

# define USE_AS_STRCAT

	/* Number of bytes in a vector register.  */
# define VEC_SIZE	32

# ifndef SECTION
#  define SECTION(p)	p##.avx
# endif

	.section SECTION(.text), "ax", @progbits
ENTRY(STRCAT)
	jmp	strcat_avx2_glibc
END(STRCAT)
#endif
