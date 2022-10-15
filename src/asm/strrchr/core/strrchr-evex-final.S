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
# include "../../libc-defs/libc-evex-vecs.h"
#endif
#if ISA_SHOULD_BUILD (4)

	// # include <sysdep.h>

# ifndef STRRCHR
#  define STRRCHR	tmp
# endif

# define VMOVU	vmovdqu64
# define VMOVA	vmovdqa64

# ifdef USE_AS_WCSRCHR
#  define RCX_M	cl
#  define SHIFT_REG	ecx
#  define VPCOMPRESS	vpcompressd
#  define kunpck_2x	kunpckbw
#  define kmov_2x	kmovd
#  define maskz_2x	ecx
#  define maskm_2x	eax
#  define CHAR_SIZE	4
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPBROADCAST	vpbroadcastd
#  define VPCMPEQ	vpcmpeqd
#  define VPCMP	vpcmpd

#  define REG_WIDTH	32
# else
#  define RCX_M	ecx
#  define SHIFT_REG	edi
#  define VPCOMPRESS	vpcompressb
#  define kunpck_2x	kunpckdq
#  define kmov_2x	kmovq
#  define maskz_2x	rcx
#  define maskm_2x	rax

#  define CHAR_SIZE	1
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPBROADCAST	vpbroadcastb
#  define VPCMPEQ	vpcmpeqb
#  define VPCMP	vpcmpb

#  define REG_WIDTH	VEC_SIZE
# endif



# include "../../libc-defs/libc-reg-macros.h"

# define VMATCH	VEC(0)
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# define PAGE_SIZE	4096



	.section .text.evex, "ax", @progbits
ENTRY(STRRCHR)
	movl	%edi, %eax
	/* Broadcast CHAR to VMATCH.  */
	VPBROADCAST %esi, %VMATCH

	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	jg	L(cross_page_boundary)

	VMOVU	(%rdi), %VEC(1)
	/* k0 has a 1 for each zero CHAR in VEC(1).  */
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VRSI
	test	%VRSI, %VRSI
	jz	L(aligned_more)
	/* fallthrough: zero CHAR in first VEC.  */
L(page_cross_return):
	/* K1 has a 1 for each search CHAR match in VEC(1).  */
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VRAX
	/* Build mask up until first zero CHAR (used to mask of
	   potential search CHAR matches past the end of the string).
	 */
	blsmsk	%VRSI, %VRSI
	and	%VRSI, %VRAX
	jz	L(ret0)
	/* Get last match (the `and` removed any out of bounds matches).
	 */
	bsr	%VRAX, %VRAX
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
	kmovV	%k1, %VRAX
	blsmsk	%VRCX, %VRCX
	/* eax non-zero if search CHAR in range.  */
	and	%VRCX, %VRAX
	jnz	L(first_vec_x1_return)

	/* fallthrough: no match in VEC(2) then need to check for
	   earlier matches (in VEC(1)).  */
	.p2align 4,, 4
L(first_vec_x0_test):
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VRAX
	test	%VRAX, %VRAX
	jz	L(ret1)
	bsr	%VRAX, %VRAX
# ifdef USE_AS_WCSRCHR
	leaq	(%rsi, %rax, CHAR_SIZE), %rax
# else
	addq	%rsi, %rax
# endif
L(ret1):
	ret

	.p2align 4,, 10
L(first_vec_x1_or_x2):
	VPCMPEQ	%VEC(3), %VMATCH, %k3
	VPCMPEQ	%VEC(2), %VMATCH, %k2
	/* K2 and K3 have 1 for any search CHAR match. Test if any
	   matches between either of them. Otherwise check VEC(1).  */
	kortestV %k2, %k3
	jz	L(first_vec_x0_test)

	/* Guranteed that VEC(2) and VEC(3) are within range so merge
	   the two bitmasks then get last result.  */
	kunpck_2x %k2, %k3, %k3
	kmov_2x	%k3, %maskm_2x
	bsr	%maskm_2x, %maskm_2x
	leaq	(VEC_SIZE * 1)(%r8, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 7
L(first_vec_x3):
	VPCMPEQ	%VMATCH, %VEC(4), %k1
	kmovV	%k1, %VRAX
	blsmsk	%VRCX, %VRCX
	/* If no search CHAR match in range check VEC(1)/VEC(2)/VEC(3).
	 */
	and	%VRCX, %VRAX
	jz	L(first_vec_x1_or_x2)
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 6
L(first_vec_x0_x1_test):
	VPCMPEQ	%VMATCH, %VEC(2), %k1
	kmovV	%k1, %VRAX
	/* Check VEC(2) for last match first. If no match try VEC(1).
	 */
	test	%VRAX, %VRAX
	jz	L(first_vec_x0_test)
	.p2align 4,, 4
L(first_vec_x1_return):
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 10
L(first_vec_x2):
	VPCMPEQ	%VMATCH, %VEC(3), %k1
	kmovV	%k1, %VRAX
	blsmsk	%VRCX, %VRCX
	/* Check VEC(3) for last match first. If no match try
	   VEC(2)/VEC(1).  */
	and	%VRCX, %VRAX
	jz	L(first_vec_x0_x1_test)
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 12
L(aligned_more):
L(page_cross_continue):
	/* Need to keep original pointer incase VEC(1) has last match.
	 */
	movq	%rdi, %rsi
	andq	$-VEC_SIZE, %rdi

	VMOVU	VEC_SIZE(%rdi), %VEC(2)
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VRCX

	test	%VRCX, %VRCX
	jnz	L(first_vec_x1)

	VMOVU	(VEC_SIZE * 2)(%rdi), %VEC(3)
	VPTESTN	%VEC(3), %VEC(3), %k0
	kmovV	%k0, %VRCX

	test	%VRCX, %VRCX
	jnz	L(first_vec_x2)

	VMOVU	(VEC_SIZE * 3)(%rdi), %VEC(4)
	VPTESTN	%VEC(4), %VEC(4), %k0
	kmovV	%k0, %VRCX
	movq	%rdi, %r8
	test	%VRCX, %VRCX
	jnz	L(first_vec_x3)

	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4,, 10
L(first_aligned_loop):
	/* Preserve VEC(1), VEC(2), VEC(3), and VEC(4) until we can
	   gurantee they don't store a match.  */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(5)
	VMOVA	(VEC_SIZE * 5)(%rdi), %VEC(6)

	VPCMPEQ	%VEC(5), %VMATCH, %k2
	vpxord	%VEC(6), %VMATCH, %VEC(7)

	VPMIN	%VEC(5), %VEC(6), %VEC(8)
	VPMIN	%VEC(8), %VEC(7), %VEC(7)

	VPTESTN	%VEC(7), %VEC(7), %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestV %k1, %k2
	jz	L(first_aligned_loop)

	VPCMPEQ	%VEC(6), %VMATCH, %k3
	VPTESTN	%VEC(8), %VEC(8), %k1

	/* If k1 is zero, then we found a CHAR match but no null-term.
	   We can now safely throw out VEC1-4.  */
	ktestV	%k1, %k1
	jz	L(second_aligned_loop_prep)

	kortestV %k2, %k3
	jnz	L(return_first_aligned_loop)


	.p2align 4,, 6
L(first_vec_x1_or_x2_or_x3):
	VPCMPEQ	%VEC(4), %VMATCH, %k4
	kmovV	%k4, %VRAX
	bsr	%VRAX, %VRAX
	jz	L(first_vec_x1_or_x2)
	leaq	(VEC_SIZE * 3)(%r8, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 8
L(return_first_aligned_loop):
	VPTESTN	%VEC(5), %VEC(5), %k0

	/* Combined results from VEC5/6.  */
	kunpck_2x %k0, %k1, %k0
	kmov_2x	%k0, %maskz_2x

	blsmsk	%maskz_2x, %maskz_2x
	kunpck_2x %k2, %k3, %k3
	kmov_2x	%k3, %maskm_2x
	and	%maskz_2x, %maskm_2x
	jz	L(first_vec_x1_or_x2_or_x3)

	bsr	%maskm_2x, %maskm_2x
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4
	/* We can throw away the work done for the first 4x checks here
	   as we have a later match. This is the 'fast' path persay.
	 */
L(second_aligned_loop_prep):
L(second_aligned_loop_set_furthest_match):
	movq	%rdi, %rsi
	/* Ideally we would safe k2/k3 but `kmov/kunpck` take uops on
	   port0 and have noticable overhead in the loop.  */
	VMOVA	%VEC(5), %VEC(7)
	VMOVA	%VEC(6), %VEC(8)
	.p2align 4
L(second_aligned_loop):
	VMOVU	(VEC_SIZE * 4)(%rdi), %VEC(5)
	VMOVU	(VEC_SIZE * 5)(%rdi), %VEC(6)
	VPCMPEQ	%VEC(5), %VMATCH, %k2
	vpxord	%VEC(6), %VMATCH, %VEC(3)

	VPMIN	%VEC(5), %VEC(6), %VEC(4)
	VPMIN	%VEC(3), %VEC(4), %VEC(3)

	VPTESTN	%VEC(3), %VEC(3), %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestV %k1, %k2
	jz	L(second_aligned_loop)
	VPCMPEQ	%VEC(6), %VMATCH, %k3
	VPTESTN	%VEC(4), %VEC(4), %k1
	ktestV	%k1, %k1
	jz	L(second_aligned_loop_set_furthest_match)

	/* branch here because we know we have a match in VEC7/8 but
	   might not in VEC5/6 so the latter is expected to be less
	   likely.  */
	kortestV %k2, %k3
	jnz	L(return_new_match)

L(return_old_match):
	VPCMPEQ	%VEC(8), %VMATCH, %k0
	kmovV	%k0, %VRCX
	bsr	%VRCX, %VRCX
	jnz	L(return_old_match_ret)

	VPCMPEQ	%VEC(7), %VMATCH, %k0
	kmovV	%k0, %VRCX
	bsr	%VRCX, %VRCX
	subq	$VEC_SIZE, %rsi
L(return_old_match_ret):
	leaq	(VEC_SIZE * 3)(%rsi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(return_new_match):
	VPTESTN	%VEC(5), %VEC(5), %k0

	/* Combined results from VEC5/6.  */
	kunpck_2x %k0, %k1, %k0
	kmov_2x	%k0, %maskz_2x

	blsmsk	%maskz_2x, %maskz_2x
	kunpck_2x %k2, %k3, %k3
	kmov_2x	%k3, %maskm_2x

	/* Match at end was out-of-bounds so use last known match.  */
	and	%maskz_2x, %maskm_2x
	jz	L(return_old_match)

	bsr	%maskm_2x, %maskm_2x
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 4
L(cross_page_boundary):
	xorq	%rdi, %rax
	mov	$-1, %VRDX
	VMOVU	(PAGE_SIZE - VEC_SIZE)(%rax), %VEC(6)
	VPTESTN	%VEC(6), %VEC(6), %k0
	kmovV	%k0, %VRSI

# ifdef USE_AS_WCSRCHR
	movl	%edi, %ecx
	and	$(VEC_SIZE - 1), %ecx
	shrl	$2, %ecx
# endif
	shlx	%VGPR(SHIFT_REG), %VRDX, %VRDX

# ifdef USE_AS_WCSRCHR
	kmovb	%edx, %k1
# else
	kmovV	%VRDX, %k1
# endif

	/* Need to adjust result to VEC(1) so it can be re-used by
	   L(return_vec_x0_test).  The alternative is to collect VEC(1)
	   will a page cross load which is far more expensive.  */
	VPCOMPRESS %VEC(6), %VEC(1){%k1}{z}

	/* We could technically just jmp back after the vpcompress but
	   it doesn't save any 16-byte blocks.  */
	shrx	%VGPR(SHIFT_REG), %VRSI, %VRSI
	test	%VRSI, %VRSI
	jz	L(page_cross_continue)

	/* Duplicate of return logic from ENTRY. Doesn't cause spill to
	   next cache line so might as well copy it here.  */
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VRAX
	blsmsk	%VRSI, %VRSI
	and	%VRSI, %VRAX
	jz	L(ret_page_cross)
	bsr	%VRAX, %VRAX
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
L(ret_page_cross):
	ret
	/* 1 byte till next cache line.  */
END(STRRCHR)
#endif
