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
#endif	/* !VEC_SIZE */
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
# else	/* !USE_AS_WCSLEN */
#  define REG_WIDTH	VEC_SIZE
#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
#  define CHAR_SIZE_SHIFT_REG(reg)
# endif	/* !USE_AS_WCSLEN */
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# include "../../libc-defs/libc-reg-macros.h"



# if CHAR_PER_VEC == 64

#  define TAIL_RETURN_LBL	first_vec_x2_check
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 2)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x3_check
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 3)

# else	/* !(CHAR_PER_VEC == 64) */

#  define TAIL_RETURN_LBL	first_vec_x3_check
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 3)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x2_check
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 2)
# endif	/* !(CHAR_PER_VEC == 64) */


# define XZERO	VEC_xmm(0)
# define VZERO	VEC(0)

	.section .text.evex, "ax", @progbits
ENTRY_P2ALIGN(STRLEN, 6)
	/* Check zero length.  */
	test	%RSI_LP, %RSI_LP
	jz	L(max_0)
# ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%esi, %esi
# endif	/* __ILP32__ */

	movl	%edi, %eax
	vpxorq	%XZERO, %XZERO, %XZERO
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes.  Each bit in K0 represents a
	   null byte.  */
	VPCMPEQ	(%rdi), %VZERO, %k0

	kmovV	%k0, %VGPR(rcx)
	movq	%rsi, %rax

	/* If src (rcx) is zero, bsf does not change the result.  */
	bsf	%VGPR(rcx), %VGPR(rax)
	/* If rax > CHAR_PER_VEC then rcx must have been zero (no null
	   CHAR) and rsi must be > CHAR_PER_VEC.  */
	cmpq	$CHAR_PER_VEC, %rax
	ja	L(aligned_more)
	/* Check if first match in bounds.  */
	cmpq	%rax, %rsi
	cmovb	%esi, %eax
	ret


	.p2align 4,, 6
L(first_vec_x0_check):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rdi, %rcx
	CHAR_SIZE_SHIFT_REG (rcx)
	addq	%rcx, %rax
	cmpq	%rax, %rsi
	cmovb	%rsi, %rax
	ret

L(first_vec_x1_check):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rdi, %rcx
	CHAR_SIZE_SHIFT_REG (rcx)
	leaq	(CHAR_PER_VEC * 1)(%rcx, %rax), %rax
	cmpq	%rax, %rsi
	cmovb	%rsi, %rax
	ret

	.p2align 4,, 6
L(TAIL_RETURN_LBL):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rdi, %rcx
	CHAR_SIZE_SHIFT_REG (rcx)
	leaq	(TAIL_RETURN_OFFSET)(%rcx, %rax), %rax
	cmpq	%rax, %rsi
	cmovb	%rsi, %rax
	ret

	.p2align 4,, 2
L(max_0):
	movl	%esi, %eax
	ret


	/* Aligned more for strnlen compares remaining length vs 2 *
	   CHAR_PER_VEC, 4 * CHAR_PER_VEC, and 8 * CHAR_PER_VEC before
	   going to the loop.  */
	.p2align 4,, 10
L(aligned_more):
	leaq	(VEC_SIZE)(%rdi), %rcx
	andq	$(VEC_SIZE * -1), %rcx
L(cross_page_continue):
	VPCMPEQ	(VEC_SIZE * 0)(%rcx), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)

# ifdef USE_AS_WCSLEN
	movq	%rdi, %rdx
	subq	%rcx, %rdx
	sarq	$2, %rdx
	leaq	(%rdx, %rsi), %rdx

# else	/* !USE_AS_WCSLEN */
	leaq	(%rsi, %rdi), %rdx
	subq	%rcx, %rdx
# endif	/* !USE_AS_WCSLEN */

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x0_check)

	/* Check the end of data.  */
	subq	$(CHAR_PER_VEC * 1), %rdx
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE * 1)(%rcx), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1_check)

	subq	$(CHAR_PER_VEC * 1), %rdx
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE * 2)(%rcx), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2_check)

	subq	$(CHAR_PER_VEC * 1), %rdx
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE * 3)(%rcx), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3_check)

	subq	$(CHAR_PER_VEC * 1), %rdx
	jbe	L(max_0)

	/* Align data to VEC_SIZE * 4.  */

	andq	$-(VEC_SIZE * 4), %rcx

	/* Compute number of words checked after aligning.  */
# ifdef USE_AS_WCSLEN
	/* Need to compute directly for wcslen as CHAR_SIZE * rsi can
	   overflow.  */
	movq	%rdi, %rdx
	subq	%rcx, %rdx
	sarq	$2, %rdx
	leaq	(%rdx, %rsi), %rdx

# else	/* !USE_AS_WCSLEN */

	/* Leave result off by one so it can be extracted with a 4 *
	   CHAR_PER_VEC - 1 mask.  */
	leaq	-(VEC_SIZE * 4 + 1)(%rdi, %rsi, CHAR_SIZE), %rdx
#  if VEC_SIZE == 64
	xorb	%dl, %dl
#  else
	andq	$-(VEC_SIZE * 4), %rdx
#  endif

# endif

	/* Compare 4 * VEC at a time forward.  */
	.p2align 4,, 11
L(loop_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rcx), %VEC(1)
	VPMINU	(VEC_SIZE * 5)(%rcx), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rcx), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rcx), %VEC(3), %VEC(4)
	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k2

	/* Break if at end of length.  */
# ifdef USE_AS_WCSLEN
	subq	$(CHAR_PER_VEC * 4), %rdx
	jb	L(loop_len_end)
# else	/* !USE_AS_WCSLEN */
	cmpq	%rcx, %rdx
	je	L(loop_len_end)
# endif	/* !USE_AS_WCSLEN */
	subq	$-(VEC_SIZE * 4), %rcx

	kortestV %k0, %k2
	jz	L(loop_4x_vec)
L(loop_last_4x):
	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x0_check)

	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1_check)

	VPTESTN	%VEC(3), %VEC(3), %k0

# if CHAR_PER_VEC == 64
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2_check)
	kmovV	%k2, %VGPR(rax)
# else	/* !(CHAR_PER_VEC == 64) */
	/* We can only combine last 2x VEC masks if CHAR_PER_VEC <= 32.
	 */
	kmovd	%k2, %edx
	kmovd	%k0, %eax
	salq	$CHAR_PER_VEC, %rdx
	orq	%rdx, %rax
# endif	/* !(CHAR_PER_VEC == 64) */
L(FALLTHROUGH_RETURN_LBL):
	bsf	%rax, %rax
	sub	%rdi, %rcx
	CHAR_SIZE_SHIFT_REG (rcx)
	leaq	(FALLTHROUGH_RETURN_OFFSET)(%rcx, %rax), %rax
	cmpq	%rax, %rsi
	cmovb	%rsi, %rax
	ret


	/* Handle last 4x VEC after loop. All VECs have been loaded.  */
	.p2align 4,, 3
L(loop_len_end):
	subq	$-(VEC_SIZE * 4), %rcx
	kortestV %k0, %k2
	jnz	L(loop_last_4x)
	movq	%rsi, %rax
	ret

	.p2align 4,, 8
L(cross_page_boundary):
	leaq	(VEC_SIZE)(%rdi), %rcx
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rcx

	VPCMPEQ	-VEC_SIZE(%rcx), %VZERO, %k0

	kmovV	%k0, %VGPR(r8)
# ifdef USE_AS_WCSLEN
	shrl	$2, %eax
	andl	$(CHAR_PER_VEC - 1), %eax
# endif	/* USE_AS_WCSLEN */
	shrx	%VGPR(rax), %VGPR(r8), %VGPR(r8)

	negl	%eax
	andl	$(CHAR_PER_VEC - 1), %eax
	movq	%rsi, %rdx
	bsf	%VGPR(r8), %VGPR(rdx)
	cmpq	%rax, %rdx
	ja	L(cross_page_continue)
	movl	%edx, %eax
	cmpq	%rdx, %rsi
	cmovb	%esi, %eax
	ret

END(STRLEN)
#endif	/* ISA_SHOULD_BUILD (4) */
