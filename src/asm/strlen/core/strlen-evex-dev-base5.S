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
	// #define USE_AS_WCSLEN
	// #define USE_AS_STRNLEN
#ifndef STRLEN
# define STRLEN	slen
#endif
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif
	// #define USE_AS_STRNLEN
#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# ifndef STRLEN
#  error "NO strlen"
# endif
	// # define USE_AS_STRNLEN
# define LEN_REG	r8
# ifdef USE_AS_WCSLEN
#  define VPCMPEQ	vpcmpeqd
#  define VPCMPNEQ	vpcmpneqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMINU	vpminud
#  define CHAR_SIZE	4
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
# endif
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

# if CHAR_PER_VEC == 64
#  define LEN_REG64	rdx
#  define LEN_REG32	edx
#  define LEN_REG_2	sil
#  define MASK_REG	al

# else
#  define LEN_REG64	rsi
#  define LEN_REG32	esi
#  define LEN_REG_2	esi
#  define MASK_REG	eax
# endif



# define XZERO	VEC_xmm(0)
# define VZERO	VEC(0)

# ifndef USE_AS_STRNLEN
	// #  define USE_AS_STRNLEN
# endif

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

# ifdef USE_AS_STRNLEN
	Vkmov	%k0, %VGPR(rcx)
	movq	%rsi, %rax
	/* If src (rcx) is zero, bsf does not change the result.  */
	bsf	%VGPR(rcx), %VGPR(rax)

	/* Two cases: 1) rcx == zero, then rax == length so this
	   comparison checks if we need to continue. Case 2) rcx is
	   non-zero, then rax == first_one(rcx) which must be <
	   $CHAR_PER_VEC, so this will ensure we try and use the match.
	 */
	cmpq	$CHAR_PER_VEC, %rax
	ja	L(aligned_more)
	cmpq	%rax, %rsi
	cmovb	%esi, %eax

# else
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
	bsf	%VGPR(rax), %VGPR(rax)
# endif

	ret

# ifdef USE_AS_STRNLEN
#  if VEC_SIZE == 64
	.p2align 4,, 2
L(zero):
L(max_0):
	movl	%esi, %eax
	ret
#  endif
	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	/* Check the first 4 * VEC_SIZE.  Only one VEC_SIZE at a time
	   since data is only aligned to VEC_SIZE.  */
#  ifdef USE_AS_STRNLEN
	/* + CHAR_SIZE because it simplies the logic in
	   last_4x_vec_or_less.  */
	// leaq    -(VEC_SIZE + 1)(%rcx, %rsi), %rdx
	// subq    %rcx, %rsi
	leaq	-(VEC_SIZE)(%rsi, %rcx), %rdx
	subq	%rdi, %rdx
#  endif
	/* Adjust length. If near end handle specially.  */

	cmpq	$(CHAR_PER_VEC * 2), %rdx
	ja	L(more_2x_vec)
L(last_2x_vec_or_less):
	VPCMPEQ	VEC_SIZE(%rdi), %VZERO, %k0
	/* Load first VEC regardless.  */
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC * 1), %edx
	jbe	L(max_0)
	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)

#  if VEC_SIZE == 64
	.p2align 4,, 3
L(last_vec_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	subl	%edx, %eax
	leal	(%eax, %esi), %eax
	cmovae	%esi, %eax
	ret
#  else
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)
L(zero):
L(max_1):
L(max_0):
	movl	%esi, %eax
	ret
#  endif



	.p2align 4,, 8
L(last_4x_vec_or_less):
	addl	$(CHAR_PER_VEC * -4), %edx
	subq	$(VEC_SIZE * -4), %rdi
	cmpl	$(CHAR_PER_VEC * 2), %edx
	jbe	L(last_2x_vec_or_less)
	.p2align 4,, 6
L(more_2x_vec):
	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	cmpq	$(CHAR_PER_VEC * 4), %rdx
	ja	L(more_4x_vec)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	addl	$(CHAR_PER_VEC * -2), %edx
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC), %edx
	jbe	L(max_1)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
#  if VEC_SIZE != 64
L(last_vec_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	subl	%edx, %eax
	leal	(%eax, %esi), %eax
	cmovae	%esi, %eax
	ret
#  else
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)
L(max_1):
	movl	%esi, %eax
	ret

	.p2align 4,, 9
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
#   ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#   endif
	leaq	CHAR_PER_VEC(%rdi, %rax), %rax
	ret

	.p2align 4,, 10
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
#   ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#   endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
#  endif
# endif


	.p2align 4,, 10
# if VEC_SIZE != 64 && (defined USE_AS_STRNLEN)
L(first_vec_x3):
	subl	$CHAR_PER_VEC, %edi
# endif
L(first_vec_x4):
	bsf	%VGPR(rax), %VGPR(rax)
	subl	%ecx, %edi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
# endif
	leal	(CHAR_PER_VEC * 4)(%rdi, %rax), %eax
	ret
# ifndef USE_AS_STRNLEN



	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
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
	cmpq	$(CHAR_PER_VEC * 8), %rdx
	jbe	L(last_4x_vec_or_less)

# endif
	subq	$(VEC_SIZE * -1), %rdi

	/* Align data to VEC_SIZE * 4.  */
# if !defined USE_AS_STRNLEN && VEC_SIZE == 64
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif

# ifdef USE_AS_STRNLEN
	leaq	-(1 + VEC_SIZE * 4)(%rcx, %rsi), %rdx
#  if VEC_SIZE == 64
	movl	%edx, %eax
#  endif
	andq	$-(VEC_SIZE * 4), %rdx
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
	cmpq	%rdi, %rdx
	je	L(loop_len_end)
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
	jnz	L(last_vec_x1)

	VPTESTN	%VEC(3), %VEC(3), %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	Vkmov	%k2, %VGPR(rax)

	.p2align 4,, 6
# if VEC_SIZE == 64 || !(defined USE_AS_STRNLEN)
L(first_vec_x3):
# endif
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
# endif
	leaq	(CHAR_PER_VEC * 3)(%rdi, %rax), %rax
	ret


	.p2align 4,, 10
# ifdef USE_AS_STRNLEN
L(last_vec_x1):
#  if VEC_SIZE != 64
L(first_vec_x1):
#  endif
	addq	$VEC_SIZE, %rdi
# endif
L(first_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
# endif
	addq	%rdi, %rax
	ret

# ifndef USE_AS_STRNLEN
	.p2align 4,, 10
L(last_vec_x1):
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 1)(%rdi, %rax), %rax
	ret
# endif

# if VEC_SIZE != 64 || !(defined USE_AS_STRNLEN)
	.p2align 4,, 10
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rcx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
# endif

# ifdef USE_AS_STRNLEN
	.p2align 4,, 10
L(loop_len_end):
#  if CHAR_PER_VEC == 64
	movzbl	%al, %edx
#  else
	leal	-1(%rsi, %rcx), %edx
	andl	$(CHAR_PER_VEC * 4 - 1), %edx
#  endif
	Vkmov	%k0, %VGPR(rcx)
#  if CHAR_PER_VEC != 64
	cmpb	$(CHAR_PER_VEC * 2), %dl
	jae	L(loop_len_end_more_2x)
#  else
	testb	%dl, %dl
	js	L(loop_len_end_more_2x)
#  endif

	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(max_end_0)
	VPTESTN	%VEC(1), %VEC(1), %k1
	Vkmov	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %edx
	jae	L(loop_len_end_mov_and_check)
L(max_end_0):
	movq	%rsi, %rax
	ret

	.p2align 4,, 6
L(loop_len_end_more_2x):

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(loop_len_end_1x_or_2x)

	Vkmov	%k2, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(max_end_1)

	VPTESTN	%VEC(3), %VEC(3), %k1
	Vkmov	%k1, %VGPR(rax)
	addl	$(CHAR_PER_VEC * -2 + 0), %edx
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %edx
	jb	L(max_end_1)
L(loop_len_end_mov_and_check):
	/* rax can't be zero here.  */
	mov	%VGPR(rcx), %VGPR(rax)
L(loop_len_end_check):
	bsf	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	subq	%rdx, %rax
	leaq	-1(%rax, %rsi), %rax
	cmova	%rsi, %rax
	ret
L(max_end_1):
	movq	%rsi, %rax
	ret

	.p2align 4,, 12
L(loop_len_end_1x_or_2x):
	VPTESTN	%VEC(1), %VEC(1), %k1
	Vkmov	%k1, %VGPR(rax)

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x0)

	mov	%VGPR(rcx), %VGPR(rax)
	subl	$CHAR_PER_VEC, %edx
L(last_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	subq	%rdx, %rsi
	leaq	-1(%rsi, %rax), %rax
	ret

# endif


	.p2align 4,, 8
L(cross_page_boundary):
	movq	%rdi, %rcx
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi
	VPCMPEQ	(%rdi), %VZERO, %k0
# ifdef USE_AS_STRNLEN
	Vkmov	%k0, %VGPR(r8)
	shrx	%VGPR(rax), %VGPR(r8), %VGPR(r8)
	negl	%eax
	andl	$(VEC_SIZE - 1), %eax
	movq	%rsi, %rdx
	bsf	%VGPR(r8), %VGPR(rdx)
	cmpq	%rax, %rdx
	ja	L(cross_page_continue)
	movl	%edx, %eax
	cmpq	%rdx, %rsi
	cmovb	%esi, %eax
# else
	Vkmov	%k0, %VGPR(rax)
	shr	%cl, %VGPR(rax)
	jz	L(cross_page_continue)
	bsf	%VGPR(rax), %VGPR(rax)
# endif
	ret

END(STRLEN)
#endif
