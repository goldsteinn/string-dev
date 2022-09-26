/* strlen/strnlen/wcslen/wcsnlen optimized with 256-bit EVEX instructions.
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
//#define USE_AS_WCSLEN
//#define USE_AS_STRNLEN
#ifndef STRLEN
# define STRLEN	slen
#endif
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif

#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# ifndef STRLEN
#  error "NO strlen"
# endif


# ifdef USE_AS_WCSLEN
#  define LEN_REG	rsi
#  define LEN_REG32	esi
#  define END_REG	r8

#  define VPCMPEQ	vpcmpeqd
#  define VPCMPNEQ	vpcmpneqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMINU	vpminud
#  define SUB_REG	rdx
#  define SUB_REG32	edx

#  define TMP_REG	rcx
#  define TMP_REG32	ecx

#  define CHAR_SIZE	4
# else
#  define LEN_REG	rdx
#  define LEN_REG32	edx
#  define END_REG	rsi

#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define SUB_REG	rcx
#  define SUB_REG32	ecx

#  define TMP_REG	r8
#  define TMP_REG32	r8d


#  define CHAR_SIZE	1
# endif
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

# if CHAR_PER_VEC == 64

# else

# endif



# define XZERO	VEC_xmm(0)
# define VZERO	VEC(0)


	.section .text.evex, "ax", @progbits
ENTRY(STRLEN)
# ifdef USE_AS_STRNLEN
	/* Check zero length.  */
	test	%RSI_LP, %RSI_LP
	jz	L(zero)
#  ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%esi, %esi
#  endif
# endif

	movl	%edi, %eax
	vpxorq	%XZERO, %XZERO, %XZERO
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes.  Each bit in K0 represents a
	   null byte.  */
	VPCMPEQ	(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
# ifdef USE_AS_STRNLEN
	cmpq	$CHAR_PER_VEC, %rsi
	jbe	L(first_vec_x0_check)
# endif
	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
	bsf	%VGPR(rax), %VGPR(rax)
	ret

# ifdef USE_AS_STRNLEN
L(zero):
	xorl	%eax, %eax
	ret

	.p2align 4,, 11
L(first_vec_x0_check):
	/* Set bit for max len so that tzcnt will return min of max len
	   and position of first match.  */
#  if REG_WIDTH == 32
	btsq	%rsi, %rax
	tzcntl	%eax, %eax
#  else
	tzcntq	%rax, %rax
	cmpl	%eax, %esi
	cmovb	%esi, %eax
#  endif
	ret

L(max_0):
	movq	%END_REG, %rax
	ret


	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %SUB_REG
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	/* Check the first 4 * VEC_SIZE.  Only one VEC_SIZE at a time
	   since data is only aligned to VEC_SIZE.  */
#  ifdef USE_AS_STRNLEN
	/* + CHAR_SIZE because it simplies the logic in
	   last_4x_vec_or_less.  */

#   ifdef USE_AS_WCSLEN
	movq	%rsi, %r8
	leal	VEC_SIZE(%rdi), %TMP_REG32
	subl	%SUB_REG32, %TMP_REG32
	shrl	$2, %TMP_REG32
	subq	%TMP_REG, %rsi
#   else
	leaq	-VEC_SIZE(%SUB_REG, %rsi), %rdx
	subq	%rdi, %rdx
#   endif
#  endif
L(last_4x_vec_or_less):
	/* Load first VEC regardless.  */
	VPCMPEQ	VEC_SIZE(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)

	/* Adjust length. If near end handle specially.  */
	cmpq	$(CHAR_PER_VEC * 2), %LEN_REG
	ja	L(more_2x_vec)

L(last_2x_vec_or_less):
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x1_check)

	/* Check the end of data.  */
	subl	$CHAR_PER_VEC, %LEN_REG32
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
L(last_vec_x1_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */

	subq	%LEN_REG, %rax
	jae	L(max_1)
	addq	%END_REG, %rax
	ret

L(max_1):
	movq	%END_REG, %rax
	ret

	.p2align 4,, 8
L(last_4x_vec_or_less_2):
	subl	$(CHAR_PER_VEC * -4), %LEN_REG32
	VPCMPEQ	(VEC_SIZE * 5)(%rdi), %VZERO, %k0
	subq	$(VEC_SIZE * -4), %rdi
	Vkmov	%k0, %VGPR(rax)


	cmpl	$(CHAR_PER_VEC * 2), %LEN_REG32
	jbe	L(last_2x_vec_or_less)

	.p2align 4,, 6
L(more_2x_vec):
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	cmpq	$(CHAR_PER_VEC * 4), %LEN_REG
	ja	L(more_4x_vec)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x3_check)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC * 3), %LEN_REG32
	jbe	L(max_2)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	subq	%LEN_REG, %rax
	jae	L(max_2)
	addq	%END_REG, %rax
	ret

	.p2align 4,, 10
L(last_vec_x3_check):
	bsf	%VGPR(rax), %VGPR(rax)
	addl	$(CHAR_PER_VEC * -2), %LEN_REG32

	/* Check the end of data.  */
	cmp	%eax, %LEN_REG32
	jbe	L(max_2)
	subq	%SUB_REG, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 3)(%rdi, %rax), %rax
	ret

L(max_2):
	movq	%END_REG, %rax
	ret

# endif

	.p2align 4,, 10
L(first_vec_x4):
	bsf	%VGPR(rax), %VGPR(rax)
	subl	%SUB_REG32, %edi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
# endif
	leal	(CHAR_PER_VEC * 4)(%rdi, %rax), %eax
	ret
# ifndef USE_AS_STRNLEN

	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %SUB_REG
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	VPCMPEQ	VEC_SIZE(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)
# else
	.p2align 4,, 10
L(more_4x_vec):
# endif

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x4)


# ifdef USE_AS_STRNLEN
	/* Check if at last VEC_SIZE * 4 length.  */
	subq	$(CHAR_PER_VEC * 8), %LEN_REG
	jbe	L(last_4x_vec_or_less_2)

# endif

	subq	$(VEC_SIZE * -1), %rdi


	/* Align data to VEC_SIZE * 4.  */
# if VEC_SIZE == 64
	/* evex512 machines having merging uop and no partial register
	   stalls.  */
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif

# ifdef USE_AS_STRNLEN
#  ifdef USE_AS_WCSLEN
	movq	%SUB_REG, %TMP_REG
	subq	%rdi, %TMP_REG
	sarq	$2, %TMP_REG
	leaq	-(CHAR_PER_VEC * 4)(%TMP_REG, %r8), %rsi
#  else
	leaq	-(VEC_SIZE * 4)(%rcx, %rsi), %LEN_REG
	subq	%rdi, %LEN_REG
#  endif
# endif

	/* Compare 4 * VEC at a time forward.  */
	.p2align 4
L(loop_4x_vec):
	/* Load first VEC regardless.  */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	// VPCMPEQ (VEC_SIZE * 4)(%rdi), %VZERO, %k1

	VPMINU	(VEC_SIZE * 5)(%rdi), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rdi), %VEC(3), %VEC(4)
	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k2

# ifdef USE_AS_STRNLEN
	/* Break if at end of length.  */
	subq	$(CHAR_PER_VEC * 4), %LEN_REG
	jbe	L(loop_len_end)
# endif

	subq	$-(VEC_SIZE * 4), %rdi
	Vkortest %k0, %k2
	jz	L(loop_4x_vec)

	VPTESTN	%VEC(1), %VEC(1), %k1
	Vkmov	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x0)

	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPTESTN	%VEC(3), %VEC(3), %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	Vkmov	%k2, %VGPR(rax)

	.p2align 4,, 6
L(first_vec_x3):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
# endif
	leaq	(CHAR_PER_VEC * 3)(%rdi, %rax), %rax
	ret

# ifdef USE_AS_WCSLEN
	.p2align 4,, 9
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	CHAR_PER_VEC(%rdi, %rax), %rax
	ret
# endif

	.p2align 4,, 10
L(first_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
# endif
	addq	%rdi, %rax
	ret

# ifndef USE_AS_WCSLEN
	.p2align 4,, 9
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	CHAR_PER_VEC(%rdi, %rax), %rax
	ret
# endif

	.p2align 4,, 10
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
# endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
# ifdef USE_AS_STRNLEN
#  if VEC_SIZE != 64
L(max_end_0):
	movq	%END_REG, %rax
	ret
#  endif

	.p2align 4
L(loop_len_end):
	Vkmov	%k0, %VGPR(TMP_REG)
	Vkmov	%k2, %VGPR(r9)
#  if CHAR_PER_VEC <= 32
	addq	%TMP_REG, %r9
#  else
	orq	%TMP_REG, %r9
#  endif
	jz	L(max_end_0)

	subl	$(CHAR_PER_VEC * -2), %LEN_REG32
	jg	L(loop_len_end_more_2x)

	VPTESTN	%VEC(1), %VEC(1), %k0
	Vkmov	%k0, %VGPR(rax)
	subl	$(CHAR_PER_VEC * -2), %LEN_REG32
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %LEN_REG32
	jg	L(loop_len_end_mov_and_check)
#  if VEC_SIZE == 64
L(max_end_0):
#  endif
L(max_end_1):
	movq	%END_REG, %rax
	ret

	.p2align 4,, 6
L(loop_len_end_more_2x):
	test	%VGPR(TMP_REG), %VGPR(TMP_REG)
	jnz	L(loop_len_end_1x_or_2x)

	VPTESTN	%VEC(3), %VEC(3), %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %LEN_REG32
	jle	L(max_end_2)
	mov	%VGPR(r9), %VGPR(TMP_REG)
L(loop_len_end_mov_and_check):
	mov	%VGPR(TMP_REG), %VGPR(rax)
L(loop_len_end_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	subq	%LEN_REG, %rax
	jae	L(max_end_2)
	addq	%END_REG, %rax
	ret

L(max_end_2):
	movq	%END_REG, %rax
	ret

	.p2align 4,, 12
L(loop_len_end_1x_or_2x):
	VPTESTN	%VEC(1), %VEC(1), %k1
	Vkmov	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x0)

	mov	%VGPR(TMP_REG), %VGPR(rax)
	addq	$VEC_SIZE, %rdi
L(last_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%SUB_REG, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 4)(%rdi, %rax), %rax
	ret

# endif
	.p2align 4,, 8
L(cross_page_boundary):
	movq	%rdi, %SUB_REG
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi
	VPCMPEQ	(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)

	/* Remove the leading bytes.  */
# ifdef USE_AS_WCSLEN
	/* NB: Divide shift count by 4 since each bit in K0 represent 4
	   bytes.  */
	movl	%SUB_REG32, %ecx
	shrl	$2, %ecx
	andl	$(CHAR_PER_VEC - 1), %ecx
# endif
	/* SHIFT_REG is ecx for USE_AS_WCSLEN and ecx otherwise.  */
	shr	%cl, %VGPR(rax)
# ifndef USE_AS_STRNLEN
	jz	L(cross_page_continue)
	bsf	%VGPR(rax), %VGPR(rax)
	ret
# else
	jnz	L(cross_page_less_vec)
#  ifndef USE_AS_WCSLEN
	movl	%SUB_REG32, %TMP_REG32
	andl	$(CHAR_PER_VEC - 1), %TMP_REG32
#  endif
	movl	$CHAR_PER_VEC, %eax
	subl	%TMP_REG32, %eax
	/* Check the end of data.  */
	cmpq	%rax, %rsi
	ja	L(cross_page_continue)
	movl	%esi, %eax
	ret
L(cross_page_less_vec):
	bsf	%VGPR(rax), %VGPR(rax)
	/* Select min of length and position of first null.  */
	cmpq	%rax, %rsi
	cmovb	%esi, %eax
	ret
# endif

END(STRLEN)
#endif
