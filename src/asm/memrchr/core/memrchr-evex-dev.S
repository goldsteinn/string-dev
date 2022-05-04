/* memrchr optimized with AVX2.
   Copyright (C) 2017-2022 Free Software Foundation, Inc.
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

# ifndef MEMRCHR
#  define MEMRCHR	__memrchr_avx2
# endif

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

// abf-off
# ifndef SECTION
#	define SECTION(p) p##.avx
# endif
// abf-on

# define PAGE_SIZE	4096
# define VEC_SIZE	32
# define YMM_MATCH	ymm16

	.section SECTION(.text), "ax", @progbits
ENTRY(MEMRCHR)
# ifdef __ILP32__
	/* Clear upper bits.  */
	and	%RDX_LP, %RDX_LP
# else
	test	%RDX_LP, %RDX_LP
# endif
	jz	L(zero_0)

	/* Get end pointer.  */
	leaq	(%rdx, %rdi), %rax
	vpbroadcastb %esi, %YMM_MATCH
	/* Check if we can load 1x VEC without cross a page.  */
	testl	$(PAGE_SIZE - VEC_SIZE), %eax
	jz	L(page_cross)

	vpcmpb	$0, -(VEC_SIZE)(%rax), %YMM_MATCH, %k0
	kmovd	%k0, %ecx
	cmpq	$VEC_SIZE, %rdx
	ja	L(more_1x_vec)
L(ret_vec_x0_test):
	lzcntl	%ecx, %ecx
	cmpl	%ecx, %edx
	jle	L(zero_0)
	subq	%rcx, %rax
    ret
L(zero_0):
	xorl	%eax, %eax
	ret

	.p2align 4,, 10
L(ret_vec_x0):
	bsrl	%ecx, %ecx
	addq	%rcx, %rax
	ret

L(more_1x_vec):

	NOP128
L(page_cross):
END(MEMRCHR)


#endif
