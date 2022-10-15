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
# include "../../libc-defs/libc-evex512-vecs.h"
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

# define LAST_VEC_CHECK_STMT(sz, check_insn, end_reg, sub_reg, offset, cmovcc, max_lbl)	\
	check_insn %VGPR(end_reg), %VGPR(end_reg);	\
	sub	%VGPR_SZ(sub_reg, sz), %VGPR_SZ(end_reg, sz);	\
	lea	(offset)(%rsi, %end_reg), %VGPR_SZ(end_reg, sz);	\
	cmovcc	%rsi, %rax;	\
	ret;

# define LAST_VEC_CHECK_LOOP(max_lbl)	LAST_VEC_CHECK_STMT(64, bsf, rax, rdx, -1, cmovg, max_lbl)
# define LAST_VEC_CHECK(max_lbl)	LAST_VEC_CHECK_STMT(32, tzcnt, rax, rdx, 0, cmovae, max_lbl)


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
	/* Check zero length.  */
	test	%RSI_LP, %RSI_LP
	jz	L(zero)
# ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%esi, %esi
# endif /* __ILP32__ */

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


# if VEC_SIZE == 64
	/* Best place for L(zero) for code position if using ZMM.  */
	.p2align 4,, 2
L(zero):
L(max_0):
	movl	%esi, %eax
	ret
# endif /* VEC_SIZE == 64 */


	/* Aligned more for strnlen compares remaining length vs 2 *
	   CHAR_PER_VEC, 4 * CHAR_PER_VEC, and 8 * CHAR_PER_VEC before
	   going to the loop.  */
	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):

	/* Compute number of words checked after aligning.  */
# ifdef USE_AS_WCSLEN
	/* Need to compute directly for wcslen as CHAR_SIZE * rsi can
	   overflow.  */
	movq	%rcx, %rdx
	subq	%rdi, %rdx
	sarq	$2, %rdx
	leaq	-(CHAR_PER_VEC * 1)(%rdx, %rsi), %rdx

# else /* !USE_AS_WCSLEN */

	leaq	-(VEC_SIZE)(%rsi, %rcx), %rdx
	subq	%rdi, %rdx
# endif /* !USE_AS_WCSLEN */


	cmpq	$(CHAR_PER_VEC * 2), %rdx
	ja	L(more_2x_vec)
L(last_2x_vec_or_less):
	VPCMPEQ	VEC_SIZE(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC * 1), %edx
	jbe	L(max_0)
	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)

# if VEC_SIZE == 64
	/* Best place for LAST_VEC_CHECK if ZMM.  */
	.p2align 4,, 6
L(last_vec_check):
	LAST_VEC_CHECK (max_last)

# else /* !(VEC_SIZE == 64) */

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)
L(zero):
L(max_1):
L(max_0):
	movl	%esi, %eax
	ret
# endif /* !(VEC_SIZE == 64) */



	.p2align 4,, 8
L(last_4x_vec_or_less):
	addl	$(CHAR_PER_VEC * -4), %edx
	subq	$(VEC_SIZE * -4), %rdi
	cmpl	$(CHAR_PER_VEC * 2), %edx
	jbe	L(last_2x_vec_or_less)
	.p2align 4,, 6
L(more_2x_vec):

	/* Remaining length >= 2 * CHAR_PER_VEC so do VEC0/VEC1 without
	   rechecking bounds.  */
	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	cmpq	$(CHAR_PER_VEC * 4), %rdx
	ja	L(more_4x_vec)


	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	addl	$(CHAR_PER_VEC * -2), %edx
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)

	subl	$(CHAR_PER_VEC), %edx
	jbe	L(max_1)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
# if VEC_SIZE != 64
	/* Best place for LAST_VEC_CHECK if YMM.  */
L(last_vec_check):
	LAST_VEC_CHECK (max_last)

# else /* !(VEC_SIZE != 64) */

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)
L(max_1):
	movl	%esi, %eax
	ret

#  ifndef USE_AS_WCSLEN
	.p2align 4,, 9
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	leaq	(CHAR_PER_VEC)(%rdi, %rax), %rax
	ret

	.p2align 4,, 9
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret

#  endif /* !USE_AS_WCSLEN */
# endif /* !(VEC_SIZE != 64) */

	.p2align 4,, 12
# if CHAR_PER_VEC != 64
L(first_vec_x3):
	subl	$VEC_SIZE, %edi
# endif /* CHAR_PER_VEC != 64 */
L(first_vec_x4):
	bsf	%VGPR(rax), %VGPR(rax)
	subl	%ecx, %edi
	CHAR_SIZE_SHIFT_REG (edi)
	leal	(CHAR_PER_VEC * 4)(%rdi, %rax), %eax
	ret



	.p2align 4,, 10
L(more_4x_vec):
	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x4)



	/* Check if at last VEC_SIZE * 4 length before aligning for the
	   loop.  */
	cmpq	$(CHAR_PER_VEC * 8), %rdx
	jbe	L(last_4x_vec_or_less)

	subq	$(VEC_SIZE * -1), %rdi

	/* Align data to VEC_SIZE * 4.  */
	andq	$-(VEC_SIZE * 4), %rdi

	/* Compute number of words checked after aligning.  */
# ifdef USE_AS_WCSLEN
	/* Need to compute directly for wcslen as CHAR_SIZE * rsi can
	   overflow.  */
	movq	%rcx, %rdx
	subq	%rdi, %rdx
	sarq	$2, %rdx
	leaq	-(1 + CHAR_PER_VEC * 4)(%rdx, %rsi), %rdx

# else /* !USE_AS_WCSLEN */

	/* Leave result off by one so it can be extracted with a 4 *
	   CHAR_PER_VEC - 1 mask.  */
	leaq	-(1 + VEC_SIZE * 4)(%rcx, %rsi, CHAR_SIZE), %rdx

#  if VEC_SIZE == 64
	/* Save value for end of maxlen.  */
	movq	%rdx, %rax
#  endif /* VEC_SIZE == 64 */
	andq	$-(VEC_SIZE * 4), %rdx
# endif /* !USE_AS_WCSLEN */

	/* Compare 4 * VEC at a time forward.  */
	.p2align 4,, 11
L(loop_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	VPMINU	(VEC_SIZE * 5)(%rdi), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rdi), %VEC(3), %VEC(4)
	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k2

	/* Break if at end of length.  */
# ifdef USE_AS_WCSLEN
	subq	$(CHAR_PER_VEC * 4), %rdx
	jb	L(loop_len_end)

# else /* !USE_AS_WCSLEN */

	cmpq	%rdi, %rdx
	je	L(loop_len_end)
# endif /* !USE_AS_WCSLEN */

	subq	$-(VEC_SIZE * 4), %rdi
	kortestV %k0, %k2
	jz	L(loop_4x_vec)

	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x0)

	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x1)

	VPTESTN	%VEC(3), %VEC(3), %k0

# if CHAR_PER_VEC == 64
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)
	kmovV	%k2, %VGPR(rax)
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

	.p2align 4,, 10
L(last_vec_x1):
# if CHAR_PER_VEC != 64
L(first_vec_x1):
# endif /* CHAR_PER_VEC != 64 */
	addq	$VEC_SIZE, %rdi
L(first_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	sub	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	addq	%rdi, %rax
	ret


	/* Handle last 4x VEC after loop. All VECs have been loaded.  */
	.p2align 4,, 10
L(loop_len_end):
# if CHAR_PER_VEC == 64
	movzbl	%al, %edx

# else /* !(CHAR_PER_VEC == 64) */

#  ifndef USE_AS_WCSLEN
	leal	-1(%rsi, %rcx), %edx
#  endif /* !USE_AS_WCSLEN */

	andl	$(CHAR_PER_VEC * 4 - 1), %edx
# endif /* !(CHAR_PER_VEC == 64) */

	kmovV	%k0, %VGPR(rcx)

	/* NB: We could save a byte of code size for ZMM version using
	   `testb %dl, %dl`. It is not needed at the moment, however.
	 */
	cmpb	$(CHAR_PER_VEC * 2), %dl
	jae	L(loop_len_end_more_2x)

	/* rcx has matches for first 2x VEC. If its zero we have no
	   remaining matches.  */
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(max_end_0)

	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %edx
# if VEC_SIZE == 64
	jae	L(loop_len_end_mov_and_check)
# else /* !(VEC_SIZE == 64) */

	jb	L(max_end_0)
L(loop_len_end_mov_and_check):
	/* rax can't be zero here.  */
	mov	%VGPR(rcx), %VGPR(rax)
L(loop_len_end_check):
	LAST_VEC_CHECK_LOOP (max_end_0)

# endif /* !(VEC_SIZE == 64) */

L(max_end_0):
	movq	%rsi, %rax
	ret

	.p2align 4,, 6
L(loop_len_end_more_2x):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(loop_len_end_1x_or_2x)

	kmovV	%k2, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(max_end_1)

	VPTESTN	%VEC(3), %VEC(3), %k1
	kmovV	%k1, %VGPR(rax)
	addl	$(CHAR_PER_VEC * -2 + 0), %edx
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %edx
# if VEC_SIZE == 64
	jb	L(max_end_1)
L(loop_len_end_mov_and_check):
	/* rax can't be zero here.  */
	mov	%VGPR(rcx), %VGPR(rax)
L(loop_len_end_check):
	LAST_VEC_CHECK_LOOP (max_end_1)
# else /* !(VEC_SIZE == 64) */
	jae	L(loop_len_end_mov_and_check)
# endif /* !(VEC_SIZE == 64) */
L(max_end_1):
	movq	%rsi, %rax
	ret

	.p2align 4,, 8
L(loop_len_end_1x_or_2x):
	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
# if CHAR_PER_VEC == 64
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x0)

	mov	%VGPR(rcx), %VGPR(rax)
	subl	$CHAR_PER_VEC, %edx
L(last_vec_x0):
# else /* !(CHAR_PER_VEC == 64) */
	salq	$CHAR_PER_VEC, %rcx
	orq	%rcx, %rax
# endif /* !(CHAR_PER_VEC == 64) */
	bsfq	%rax, %rax
	/* Since we near end of maxlen, compute result by subtracting
	   position of null-term from maxlen.  */
	subq	%rdx, %rsi
	leaq	-1(%rsi, %rax), %rax
	ret


	.p2align 4,, 8
L(cross_page_boundary):
	movq	%rdi, %rcx
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi

	VPCMPEQ	(%rdi), %VZERO, %k0

	kmovV	%k0, %VGPR(r8)
# ifdef USE_AS_WCSLEN
	shrl	$2, %eax
	andl	$(CHAR_PER_VEC - 1), %eax
# endif /* USE_AS_WCSLEN */
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
#endif /* ISA_SHOULD_BUILD (4) */
