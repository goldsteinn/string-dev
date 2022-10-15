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
#  define SHIFT_REG	ecx
#  define VPCOMPRESS	vpcompressd
#  if VEC_SIZE == 64
#   define kunpck_2x	kunpckwd
#  else
#   define kunpck_2x	kunpckbw
#  endif
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
#  define SHIFT_REG	edi
#  define VPCOMPRESS	vpcompressb
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

# if CHAR_PER_VEC == 8
#  define RCX_M	cl
#  define kortestM	kortestb
# elif CHAR_PER_VEC == 16
#  define RCX_M	cx
#  define kortestM	kortestw
# elif CHAR_PER_VEC == 32
#  define RCX_M	ecx
#  define kortestM	kortestd
# else
#  define RCX_M	rcx
#  define kortestM	kortestq
# endif

	.section .text.evex, "ax", @progbits
ENTRY(STRRCHR)
	movl	%edi, %eax
	/* Broadcast CHAR to VMATCH.  */
	VPBROADCAST %esi, %VMATCH

	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	jg	L(cross_page_boundary)

	VMOVU	(%rdi), %VEC(1)
	/* k0 has a 1 for each zero CHAR in YMM1.  */
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VGPR(rsi)
	test	%VGPR(rsi), %VGPR(rsi)
	jz	L(aligned_more)
	/* fallthrough: zero CHAR in first VEC.  */
L(page_cross_return):
	/* K1 has a 1 for each search CHAR match in VEC(1).  */
	VPCMPEQ	%VMATCH, %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	/* Build mask up until first zero CHAR (used to mask of
	   potential search CHAR matches past the end of the string).
	 */
	blsmsk	%VGPR(rsi), %VGPR(rsi)
	and	%VGPR(rsi), %VGPR(rax)
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



# define NO_CODE	1

# if REG_WIDTH == 64
	.p2align 4,, 10
L(first_vec_x3):
#  if NO_CODE
	VPCMPEQ	%VMATCH, %VEC(4), %k1
	kmovV	%k1, %VGPR(rax)
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	/* If no search CHAR match in range check YMM1/YMM2/YMM3.  */
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(first_vec_x1_or_x2)
	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	ret
#  endif
	.p2align 4,, 4
# else
	.p2align 4,, 10
# endif



L(first_vec_x2):
# if NO_CODE
	VPCMPEQ	%VMATCH, %VEC(3), %k1
	kmovV	%k1, %VGPR(rax)
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	/* Check YMM3 for last match first. If no match try YMM2/YMM1.
	 */
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(first_vec_x0_x1_test)
	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 2)(%r8, %rax, CHAR_SIZE), %rax
	ret
# endif

	.p2align 4,, 6
L(first_vec_x0_x1_test):
# if NO_CODE
	VPCMPEQ	%VMATCH, %VEC(2), %k1
	kmovV	%k1, %VGPR(rax)
	/* Check YMM2 for last match first. If no match try YMM1.  */
	test	%VGPR(rax), %VGPR(rax)
	jz	L(first_vec_x0_test)
# endif
	.p2align 4,, 4
L(first_vec_x1_return):
	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE)(%r8, %rax, CHAR_SIZE), %rax
	ret


# if REG_WIDTH == 32
	.p2align 4,, 10
L(first_vec_x3):
#  if NO_CODE
	VPCMPEQ	%VMATCH, %VEC(4), %k1
	kmovV	%k1, %VGPR(rax)
	blsmsk	%VGPR(rcx), %VGPR(rcx)
	/* If no search CHAR match in range check YMM1/YMM2/YMM3.  */
	and	%VGPR(rcx), %VGPR(rax)
	jz	L(first_vec_x1_or_x2)
	bsr	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	ret
#  endif
# endif


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
	movq	%rdi, %r8
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

	test	%VRCX, %VRCX
	jnz	L(first_vec_x3)

	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4
L(first_aligned_loop):
	/* Preserve VEC(1), VEC(2), VEC(3), and VEC(4) until we can
	   gurantee they don't store a match.  */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(5)
	VMOVA	(VEC_SIZE * 5)(%rdi), %VEC(6)

# if VEC_SIZE == 64
	VPCMP	$4, %VEC(5), %VMATCH, %k2
	VPCMP	$4, %VEC(6), %VMATCH, %k3{%k2}

	VPMIN	%VEC(5), %VEC(6), %VEC(7)

	VPTEST	%VEC(7), %VEC(7), %k1{%k3}
	subq	$(VEC_SIZE * -2), %rdi
	kmovV	%k1, %VRCX
	inc	%RCX_M
# else
	VPCMPEQ	%VEC(5), %VMATCH, %k2
	vpxord	%VEC(6), %VMATCH, %VEC(7)

	VPMIN	%VEC(5), %VEC(6), %VEC(8)
	VPMIN	%VEC(8), %VEC(7), %VEC(7)

	VPTESTN	%VEC(7), %VEC(7), %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestV %k1, %k2
# endif
	jz	L(first_aligned_loop)

# if VEC_SIZE == 64
	VPTESTN	%VEC(7), %VEC(7), %k1
	kmovV	%k1, %VRDX
	test	%VRDX, %VRDX
# else
	VPCMPEQ	%VEC(6), %VMATCH, %k3
	VPTESTN	%VEC(8), %VEC(8), %k1
	ktestV	%k1, %k1
# endif
	jz	L(second_aligned_loop_prep)

# if VEC_SIZE == 64
	kortestM %k3, %k3
	jnc	L(return_first_aligned_loop)
# else
	kortestV %k2, %k3
	jnz	L(return_first_aligned_loop)
# endif



	.p2align 4,, 6
L(first_vec_x1_or_x2_or_x3):
	VPCMPEQ	%VEC(4), %VMATCH, %k4
	kmovV	%k4, %VRAX
	test	%VRAX, %VRAX
	jz	L(first_vec_x1_or_x2)
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 3)(%r8, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 8
L(return_first_aligned_loop):
	VPTESTN	%VEC(5), %VEC(5), %k0
# if VEC_SIZE == 64
	kmovV	%k0, %VRCX
	blsmsk	%VRCX, %VRCX
	jnc	L(return_first_new_match_first)
	blsmsk	%VRDX, %VRDX
	VPCMPEQ	%VEC(6), %VMATCH, %k0
	kmovV	%k0, %VRAX
	addq	$VEC_SIZE, %rdi
	and	%VRDX, %VRAX
	jnz	L(return_first_new_match_ret)
	subq	$VEC_SIZE, %rdi
L(return_first_new_match_first):
	kmovV	%k2, %VRAX
#  ifdef USE_AS_WCSRCHR
	xorl	$((1 << CHAR_PER_VEC)- 1), %VRAX
	and	%VRCX, %VRAX
#  else
	andn	%VRCX, %VRAX, %VRAX
#  endif
	jz	L(first_vec_x1_or_x2_or_x3)
L(return_first_new_match_ret):
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret
# else
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
# endif


# if REG_WIDTH == 32
	.p2align 4,, 10
L(first_vec_x1_or_x2):
	VPCMPEQ	%VEC(3), %VMATCH, %k3
	VPCMPEQ	%VEC(2), %VMATCH, %k2
	/* K2 and K3 have 1 for any search CHAR match. Test if any
	   matches between either of them. Otherwise check YMM1.  */
	kortestV %k2, %k3
	jz	L(first_vec_x0_test)

	/* Guranteed that VEC(2) and YMM3 are within range so merge the
	   two bitmasks then get last result.  */
	kunpck_2x %k2, %k3, %k3
	kmov_2x	%k3, %maskm_2x
	bsr	%maskm_2x, %maskm_2x
	leaq	(VEC_SIZE * 1)(%r8, %rax, CHAR_SIZE), %rax
	ret
# endif
# if REG_WIDTH == 64
	.p2align 4,, 10
L(first_vec_x1_or_x2):
	VPCMPEQ	%VEC(3), %VMATCH, %k3
	kmovV	%k3, %VRAX
	test	%VRAX, %VRAX
	jz	L(first_vec_x0_x1_test)
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 2)(%r8, %rax, CHAR_SIZE), %rax
	ret
# endif


	.p2align 4
	/* We can throw away the work done for the first 4x checks here
	   as we have a later match. This is the 'fast' path persay.
	 */
L(second_aligned_loop_prep):
L(second_aligned_loop_set_furthest_match):
	movq	%rdi, %rsi
	VMOVA	%VEC(5), %VEC(7)
	VMOVA	%VEC(6), %VEC(8)
	.p2align 4
L(second_aligned_loop):
	VMOVU	(VEC_SIZE * 4)(%rdi), %VEC(5)
	VMOVU	(VEC_SIZE * 5)(%rdi), %VEC(6)
# if VEC_SIZE == 64
	VPCMP	$4, %VEC(5), %VMATCH, %k2
	VPCMP	$4, %VEC(6), %VMATCH, %k3{%k2}

	VPMIN	%VEC(5), %VEC(6), %VEC(4)

	VPTEST	%VEC(4), %VEC(4), %k1{%k3}
	subq	$(VEC_SIZE * -2), %rdi
	kmovV	%k1, %VRCX
	inc	%RCX_M
# else
	VPCMPEQ	%VEC(5), %VMATCH, %k2
	vpxord	%VEC(6), %VMATCH, %VEC(3)

	VPMIN	%VEC(5), %VEC(6), %VEC(4)
	VPMIN	%VEC(3), %VEC(4), %VEC(3)

	VPTESTN	%VEC(3), %VEC(3), %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestV %k1, %k2
# endif
	jz	L(second_aligned_loop)
# if VEC_SIZE == 64
	VPTESTN	%VEC(4), %VEC(4), %k1
	kmovV	%k1, %VRDX
	test	%VRDX, %VRDX
# else
	VPCMPEQ	%VEC(6), %VMATCH, %k3
	VPTESTN	%VEC(4), %VEC(4), %k1
	ktestV	%k1, %k1
# endif
	jz	L(second_aligned_loop_set_furthest_match)

# if VEC_SIZE == 64
	kortestM %k3, %k3
	jnc	L(return_new_match)
# else
	kortestV %k2, %k3
	jnz	L(return_new_match)
# endif
	/* branch here because there is a significant advantage interms
	   of output dependency chance in using edx.  */


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


L(return_new_match):
	VPTESTN	%VEC(5), %VEC(5), %k0
# if VEC_SIZE == 64
	kmovV	%k0, %VRCX
	blsmsk	%VRCX, %VRCX
	jnc	L(return_new_match_first)
	dec	%VRDX
	VPCMPEQ	%VEC(6), %VMATCH, %k0
	kmovV	%k0, %VRAX
	addq	$VEC_SIZE, %rdi
	and	%VRDX, %VRAX
	jnz	L(return_new_match_ret)
	subq	$VEC_SIZE, %rdi
L(return_new_match_first):
	kmovV	%k2, %VRAX
#  ifdef USE_AS_WCSRCHR
	xorl	$((1 << CHAR_PER_VEC)- 1), %VRAX
	and	%VRCX, %VRAX
#  else
	andn	%VRCX, %VRAX, %VRAX
#  endif
	jz	L(return_old_match)
L(return_new_match_ret):
	bsr	%VRAX, %VRAX
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret
# else
	kunpck_2x %k0, %k1, %k0
	kmov_2x	%k0, %maskz_2x

	blsmsk	%maskz_2x, %maskz_2x
	kunpck_2x %k2, %k3, %k3
	kmov_2x	%k3, %maskm_2x
	and	%maskz_2x, %maskm_2x
	jz	L(return_old_match)

	bsr	%maskm_2x, %maskm_2x
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret
# endif

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

# if CHAR_PER_VEC == 8
	kmovb	%edx, %k1
# elif CHAR_PER_VEC == 16
	kmovw	%edx, %k1
# else
	kmovV	%VRDX, %k1
# endif

	VPCOMPRESS %VEC(6), %VEC(5){%k1}{z}
	/* We could technically just jmp back after the vpcompress but
	   it doesn't save any 16-byte blocks.  */

	shrx	%VGPR(SHIFT_REG), %VRSI, %VRSI
	test	%VRSI, %VRSI
	jnz	L(page_cross_return)
	jmp	L(page_cross_continue)


END(STRRCHR)
#endif
