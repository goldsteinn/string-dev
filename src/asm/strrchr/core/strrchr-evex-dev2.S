/* strrchr/wcsrchr optimized with 256-bit EVEX instructions.
   Copyright (C) 2021-2022 Free Software Foundation, Inc.
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
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex512-vecs.h"
#endif
#if ISA_SHOULD_BUILD (4)

	// # include <sysdep.h>

# ifndef STRRCHR
#  define STRRCHR	tmp
# endif

# define VMOVU	vmovdqu64
# define VMOVA	vmovdqa64

# ifdef USE_AS_WCSRCHR
#  define SHIFT_REG	esi

#  define kunpck_2x	kunpckbw
#  define kmov_2x	kmovd
#  define maskz_2x	ecx
#  define maskm_2x	eax
#  define CHAR_SIZE	4
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPCMPEQ	vpcmpeqd

#  define REG_WIDTH	32
# else
#  define SHIFT_REG	edi

#  if VEC_SIZE == 32
	/* Don't defined these for VEC_SIZE == 64 to avoid silent bugs.
	 */
#   define kunpck_2x	kunpckdq
#   define kmov_2x	kmovq
#   define maskz_2x	rcx
#   define maskm_2x	rax
#  endif

#  define CHAR_SIZE	1
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPBROADCAST	vpbroadcastb
#  define VPCMPEQ	vpcmpeqb

#  define REG_WIDTH	VEC_SIZE
# endif

# include "../../libc-defs/libc-reg-macros.h"

# define VMATCH	VEC(0)

# define PAGE_SIZE	4096
	.section .text.evex, "ax", @progbits
ENTRY(STRRCHR)
	movl	%edi, %eax
	/* Broadcast CHAR to VMATCH.  */
	VPBROADCAST %esi, %VMATCH

	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	jg	L(cross_page_boundary)

L(page_cross_continue):
	VMOVU	(%rdi), %VEC(1)
	/* k0 has a 1 for each zero CHAR in YMM1.  */
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(aligned_more)
	/* fallthrough: zero CHAR in first VEC.  */

	/* K1 has a 1 for each search CHAR match in VEC(1).  */
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	/* Build mask up until first zero CHAR (used to mask of
	   potential search CHAR matches past the end of the string).
	 */
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(ret0)
	/* Get last match (the `and` removed any out of bounds matches).
	 */
	bsr	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
L(ret0):
	ret

	/* Returns for first vec x1/x2/x3 have hard coded backward
	   search path for earlier matches.  */
	.p2align 4,, 6
L(first_vec_x1):
	VPCMPEQ	%VMATCH, %VEC(2), %k1
	kmovV	%k1, %VGPR(rax)
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	/* eax non-zero if search CHAR in range.  */
	and	%VGPR(rcx), %VGPR(rax)
	jnz	L(first_vec_x1_return)

	/* fallthrough: no match in YMM2 then need to check for earlier
	   matches (in YMM1).  */
	.p2align 4,, 4
L(first_vec_x0_test):
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jz	L(ret1)
	bsr	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WCSRCHR
	leaq	(%rsi, %rax, CHAR_SIZE), %rax
# else
	addq	%rsi, %rax
# endif
L(ret1):
	ret

	.p2align 4,, 6
L(first_vec_x0_x1_test):
	VPCMPEQ	%VMATCH, %VEC(2), %k1
	kmovV	%k1, %VGPR(rax)
	/* Check YMM2 for last match first. If no match try YMM1.  */
	test	%VGPR(rax), %VGPR(rax)
	jz	L(first_vec_x0_test)
	.p2align 4,, 4
L(first_vec_x1_return):
	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE)(%rdx, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 4
L(aligned_more):
	/* Need to keep original pointer incase VEC(1) has last match.
	 */
	movq	%rdi, %rsi
	andq	$-VEC_SIZE, %rdi
	VMOVU	VEC_SIZE(%rdi), %VEC(2)
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	movq	%rdi, %rdx
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x1)

	.p2align 4
L(first_aligned_loop):
	/* Preserve VEC(1), YMM2, YMM3, and YMM4 until we can gurantee
	   they don't store a match.  */
	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(4)

	VPCMPEQ	%VEC(4), %VMATCH, %k1
	VPTESTN	%VEC(4), %VEC(4), %k2
	subq	$(VEC_SIZE * -1), %rdi
	kortestV %k1, %k2
	jz	L(first_aligned_loop)

	ktestV	%k2, %k2
	jz	L(second_aligned_loop_prep)

	.p2align 4,, 6
	kmovV	%k2, %VGPR(rcx)
	kmovV	%k1, %VGPR(rax)
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(first_vec_x0_x1_test)

	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(second_aligned_loop_prep):
L(second_aligned_loop_set_furthest_match):
	movq	%rdi, %rsi
	kmovV	%k1, %rcx
	.p2align 4
L(second_aligned_loop):
	VMOVU	(VEC_SIZE * 2)(%rdi), %VEC(1)

	VPCMPEQ	%VEC(1), %VMATCH, %k1
	VPTESTN	%VEC(1), %VEC(1), %k2

	subq	$(VEC_SIZE * -1), %rdi
	kortestV %k1, %k2
	jz	L(second_aligned_loop)

	ktestV	%k2, %k2
	jz	L(second_aligned_loop_set_furthest_match)

	ktestV	%k1, %k1
	jnz	L(return_new_match)
L(return_old_match):
	bsrq	%rcx, %rcx
	leaq	(VEC_SIZE * 1)(%rsi, %rcx, CHAR_SIZE), %rax
	ret

L(return_new_match):
	kmovV	%k2, %rdx
	blsmsk	%rdx, %rdx
	kmovV	%k1, %rax
	and	%rdx, %rax
	jz	L(return_old_match)

	bsr	%rax, %rax
	leaq	(VEC_SIZE * 1)(%rdi, %rax, CHAR_SIZE), %rax
	ret

L(cross_page_boundary):
	/* eax contains all the page offset bits of src (rdi). `xor rdi,
	   rax` sets pointer will all page offset bits cleared so
	   offset of (PAGE_SIZE - VEC_SIZE) will get last aligned VEC
	   before page cross (guranteed to be safe to read). Doing this
	   as opposed to `movq %rdi, %rax; andq $-VEC_SIZE, %rax` saves
	   a bit of code size.  */
	xorq	%rdi, %rax
	VMOVU	(PAGE_SIZE - VEC_SIZE)(%rax), %VEC(1)
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VGPR(rcx)

	/* Shift out zero CHAR matches that are before the begining of
	   src (rdi).  */
# ifdef USE_AS_WCSRCHR
	movl	%edi, %esi
	and	$(VEC_SIZE - 1), %esi
	shrl	$2, %esi
# endif
	shrx	%VGPR(SHIFT_REG), %VGPR(rcx), %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(page_cross_continue)

	/* Found zero CHAR so need to test for search CHAR.  */
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	/* Shift out search CHAR matches that are before the begining of
	   src (rdi).  */
	shrx	%VGPR(SHIFT_REG), %VGPR(rax), %VGPR(rax)

	/* Check if any search CHAR match in range.  */
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(ret3)
	bsr	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
L(ret3):
	ret

END(STRRCHR)
#endif
