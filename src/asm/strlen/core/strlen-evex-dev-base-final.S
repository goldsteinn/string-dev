/* Placeholder function, not used by any processor at the moment.
   Copyright (C) 2022 Free Software Foundation, Inc.
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

/* UNUSED. Exists purely as reference implementation.  */
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif /* !VEC_SIZE */
	// #define USE_AS_STRNLEN
#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)


# ifdef USE_AS_WCSLEN
#  define REG_WIDTH	32
#  define VPCMPEQ	vpcmpeqd
#  define VPCMPNEQ	vpcmpneqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMINU	vpminud
#  define CHAR_SIZE	4
#  define CHAR_SIZE_SHIFT_REG(reg)	sar $2, %reg
# else /* !USE_AS_WCSLEN */
#  define REG_WIDTH	VEC_SIZE
#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
#  define CHAR_SIZE_SHIFT_REG(reg)
# endif /* !USE_AS_WCSLEN */
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

# include "../../libc-defs/libc-reg-macros.h"

# if CHAR_PER_VEC == 64

#  define TAIL_RETURN_LBL	first_vec_x2
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 2)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x3
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 3)

# else /* !(CHAR_PER_VEC == 64) */

#  define TAIL_RETURN_LBL	first_vec_x3
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 3)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x2
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 2)
# endif /* !(CHAR_PER_VEC == 64) */

# define XZERO	VEC_xmm(0)
# define VZERO	VEC(0)

	.section .text.evex, "ax", @progbits
ENTRY_P2ALIGN(STRLEN, 6)
	movl	%edi, %eax
	vpxorq	%XZERO, %XZERO, %XZERO
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes.  Each bit in K0 represents a
	   null byte.  */
	VPCMPEQ	(%rdi), %VZERO, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jz	L(aligned_more)
	bsf	%VRAX, %VRAX
	ret

	.p2align 4,, 8
L(first_vec_x4):
	bsf	%VRAX, %VRAX
	subl	%ecx, %edi
	CHAR_SIZE_SHIFT_REG (edi)
	leal	(CHAR_PER_VEC * 4)(%rdi, %rax), %eax
	ret



	/* Aligned more for strnlen compares remaining length vs 2 *
	   CHAR_PER_VEC, 4 * CHAR_PER_VEC, and 8 * CHAR_PER_VEC before
	   going to the loop.  */
	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	/* Remaining length >= 2 * CHAR_PER_VEC so do VEC0/VEC1 without
	   rechecking bounds.  */
	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VZERO, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x4)

	subq	$(VEC_SIZE * -1), %rdi

# if CHAR_PER_VEC == 64
	/* No partial register stalls on processors that we use evex512
	   on and this saves code size.  */
	xorb	%dil, %dil
# else /* !(VEC_SIZE == 64) */
	andq	$-(VEC_SIZE * 4), %rdi
# endif /* !(VEC_SIZE == 64) */



	/* Compare 4 * VEC at a time forward.  */
	.p2align 4
L(loop_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	VPMINU	(VEC_SIZE * 5)(%rdi), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rdi), %VEC(3), %VEC(4)
	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k2

	subq	$-(VEC_SIZE * 4), %rdi
	kortestV %k0, %k2
	jz	L(loop_4x_vec)

	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x0)

	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x1)

	VPTESTN	%VEC(3), %VEC(3), %k0

# if CHAR_PER_VEC == 64
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x2)
	kmovV	%k2, %VRAX
# else /* !(CHAR_PER_VEC == 64) */
	/* We can only combine last 2x VEC masks if CHAR_PER_VEC <= 32.
	 */
	kmovd	%k2, %edx
	kmovd	%k0, %eax
	salq	$CHAR_PER_VEC, %rdx
	orq	%rdx, %rax
# endif /* !(CHAR_PER_VEC == 64) */

	/* first_vec_x3 for strlen-ZMM and first_vec_x2 for strlen-YMM.
	 */
	.p2align 4,, 2
L(FALLTHROUGH_RETURN_LBL):
	bsfq	%rax, %rax
	subq	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	leaq	(FALLTHROUGH_RETURN_OFFSET)(%rdi, %rax), %rax
	ret

	.p2align 4,, 8
L(first_vec_x0):
	bsf	%VRAX, %VRAX
	sub	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	addq	%rdi, %rax
	ret

	.p2align 4,, 10
L(first_vec_x1):
	bsf	%VRAX, %VRAX
	sub	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	leaq	(CHAR_PER_VEC)(%rdi, %rax), %rax
	ret

	.p2align 4,, 10
	/* first_vec_x2 for strlen-ZMM and first_vec_x3 for strlen-YMM.
	 */
L(TAIL_RETURN_LBL):
	bsf	%VRAX, %VRAX
	sub	%VRCX, %VRDI
	CHAR_SIZE_SHIFT_REG (VRDI)
	lea	(TAIL_RETURN_OFFSET)(%rdi, %rax), %VRAX
	ret

	.p2align 4,, 8
L(cross_page_boundary):
	movq	%rdi, %rcx
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi

	VPCMPEQ	(%rdi), %VZERO, %k0

	kmovV	%k0, %VRAX
# ifdef USE_AS_WCSLEN
	movl	%ecx, %edx
	shrl	$2, %edx
	andl	$(CHAR_PER_VEC - 1), %edx
	shrx	%edx, %eax, %eax
	testl	%eax, %eax
# else /* !USE_AS_WCSLEN */
	shr	%cl, %VRAX
# endif /* !USE_AS_WCSLEN */
	jz	L(cross_page_continue)
	bsf	%VRAX, %VRAX

	ret

END(STRLEN)
#endif /* ISA_SHOULD_BUILD (4) */
