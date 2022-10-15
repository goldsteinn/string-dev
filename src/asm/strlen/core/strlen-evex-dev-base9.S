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
	// #define USE_AS_STRNLEN
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex512-vecs.h"
#endif
	// #define USE_AS_STRNLEN
#include "../../libc-asm-common.h"
#include "../../libc-defs/libc-reg-macros.h"
#if ISA_SHOULD_BUILD (4)

# ifndef STRLEN
#  error "NO strlen"
# endif

# ifndef USE_AS_STRNLEN
//#  define USE_AS_STRNLEN
//#  define USE_AS_WCSLEN
# endif

	// # define USE_AS_STRNLEN
# ifdef USE_AS_WCSLEN
#  define VPCMPEQ	vpcmpeqd
#  define VPCMPNEQ	vpcmpneqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMINU	vpminud
#  define CHAR_SIZE	4
#  define CHAR_SIZE_SHIFT_REG(reg)	sar $2, %reg
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
#  define CHAR_SIZE_SHIFT_REG(reg)
# endif
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)


# define VEC_RETURN_STMT(sz, end_reg, sub_reg, base_reg, add_stmt, ...)	\
	bsf	%VGPR(end_reg), %VGPR(end_reg);	\
	sub	%VGPR_SZ(sub_reg, sz), %VGPR_SZ(base_reg, sz);	\
	CHAR_SIZE_SHIFT_REG (VGPR_SZ(base_reg, sz));	\
	add_stmt (sz, base_reg, end_reg, __VA_ARGS__);	\
	ret;	\

# define add_stmt2(sz, x, y, ...)	add %VGPR_SZ(x, sz), %VGPR_SZ(y, sz)
# define add_stmt3(sz, x, y, c)	lea (c)(%x, %y), %VGPR_SZ(y, sz)

# define FIRST_VEC_X0(sz)	VEC_RETURN_STMT(sz, rax, rcx, rdi, add_stmt2)
# define FIRST_VEC_X1(sz)	VEC_RETURN_STMT(sz, rax, rcx, rdi, add_stmt3, CHAR_PER_VEC)
# define FIRST_VEC_X2(sz)	VEC_RETURN_STMT(sz, rax, rcx, rdi, add_stmt3, CHAR_PER_VEC * 2)
# define FIRST_VEC_X3(sz)	VEC_RETURN_STMT(sz, rax, rcx, rdi, add_stmt3, CHAR_PER_VEC * 3)
# define FIRST_VEC_X4(sz)	VEC_RETURN_STMT(sz, rax, rcx, rdi, add_stmt3, CHAR_PER_VEC * 4)

# define LAST_VEC_CHECK_STMT(sz, check_insn, end_reg, sub_reg, offset, cmovcc, max_lbl)	\
	check_insn %VGPR(end_reg), %VGPR(end_reg);	\
	sub	%VGPR_SZ(sub_reg, sz), %VGPR_SZ(end_reg, sz);	\
	lea	(offset)(%rsi, %end_reg), %VGPR_SZ(end_reg, sz);	\
	cmovcc	%rsi, %rax;	\
	ret;

# define LAST_VEC_CHECK_LOOP(max_lbl)	LAST_VEC_CHECK_STMT(64, bsf, rax, rdx, -1, cmovg, max_lbl)
# define LAST_VEC_CHECK(max_lbl)	LAST_VEC_CHECK_STMT(32, tzcnt, rax, rdx, 0, cmovae, max_lbl)

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
# ifdef USE_AS_STRNLEN
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
# else
	kmovV	%k0, %VGPR(rax)
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

	/* Aligned more for strnlen compares remaining length vs 2 *
	   CHAR_PER_VEC, 4 * CHAR_PER_VEC, and 8 * CHAR_PER_VEC before
	   going to the loop.  */
	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	/* Compute number of words checked after aligning.  */
#  ifdef USE_AS_WCSLEN
	/* Need to compute directly for wcslen as CHAR_SIZE * rsi can
	   overflow.  */
	movq	%rcx, %rdx
	subq	%rdi, %rdx
	sarq	$2, %rdx
	leaq	-(CHAR_PER_VEC * 1)(%rdx, %rsi), %rdx
#  else
	leaq	-(VEC_SIZE)(%rsi, %rcx), %rdx
	subq	%rdi, %rdx
#  endif


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

#  if VEC_SIZE == 64
	.p2align 4,, 6
L(last_vec_check):
	LAST_VEC_CHECK (max_last)
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
#  if VEC_SIZE != 64
L(last_vec_check):
	LAST_VEC_CHECK (max_last)
#  else
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_check)
L(max_1):
	movl	%esi, %eax
	ret

#   ifndef USE_AS_WCSLEN
	.p2align 4,, 9
L(first_vec_x1):
	FIRST_VEC_X1 (32)
	.p2align 4,, 9
L(first_vec_x2):
	FIRST_VEC_X2 (64)
#   endif
#  endif
# endif


	.p2align 4,, 10
# if CHAR_PER_VEC != 64 && (defined USE_AS_STRNLEN)
L(first_vec_x3):
	subl	$VEC_SIZE, %edi
# endif
L(first_vec_x4):
	FIRST_VEC_X4 (32)

# ifndef USE_AS_STRNLEN
	.p2align 4,, 10
L(aligned_more):
	movq	%rdi, %rcx
	andq	$(VEC_SIZE * -1), %rdi
L(cross_page_continue):
	VPCMPEQ	VEC_SIZE(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)
# else
	.p2align 4,, 10
L(more_4x_vec):
# endif

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VZERO, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x4)


# ifdef USE_AS_STRNLEN
	/* Check if at last VEC_SIZE * 4 length before aligning for the
	   loop.  */
	cmpq	$(CHAR_PER_VEC * 8), %rdx
	jbe	L(last_4x_vec_or_less)

# endif
	subq	$(VEC_SIZE * -1), %rdi
	/* Align data to VEC_SIZE * 4.  */
# if !defined USE_AS_STRNLEN && VEC_SIZE == 64
	/* No partial register stalls on processors that we use evex512
	   on and this saves code size.  */
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif


# if defined USE_AS_STRNLEN
	/* Compute number of words checked after aligning.  */
#  ifdef USE_AS_WCSLEN
	/* Need to compute directly for wcslen as CHAR_SIZE * rsi can
	   overflow.  */
	movq	%rcx, %rdx
	subq	%rdi, %rdx
	sarq	$2, %rdx
	leaq	-(1 + CHAR_PER_VEC * 4)(%rdx, %rsi), %rdx
#  else
	/* Leave result off by one so it can be extracted with a 4 *
	   CHAR_PER_VEC - 1 mask.  */
	leaq	-(1 + VEC_SIZE * 4)(%rcx, %rsi, CHAR_SIZE), %rdx
#   if VEC_SIZE == 64
	/* Save value for end of maxlen.  */
	movq	%rdx, %rax
#   endif
	andq	$-(VEC_SIZE * 4), %rdx
#  endif
# endif


	/* Compare 4 * VEC at a time forward.  */
	.p2align 4
L(loop_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	VPMINU	(VEC_SIZE * 5)(%rdi), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rdi), %VEC(3), %VEC(4)
	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k2

# ifdef USE_AS_STRNLEN
	/* Break if at end of length.  */
#  ifdef USE_AS_WCSLEN
	subq	$(CHAR_PER_VEC * 4), %rdx
	jb	L(loop_len_end)
#  else
	cmpq	%rdi, %rdx
	je	L(loop_len_end)
#  endif
# endif

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

	.p2align 4,, 6
L(first_vec_x3):
	FIRST_VEC_X3 (64)
# else
	kmovd	%k2, %edx
	kmovd	%k0, %eax
	salq	$CHAR_PER_VEC, %rdx
	orq	%rdx, %rax
	.p2align 4,, 2
L(first_vec_x2):
	bsfq	%rax, %rax
	subq	%rcx, %rdi
	CHAR_SIZE_SHIFT_REG (rdi)
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
# endif

	.p2align 4,, 10
# ifdef USE_AS_STRNLEN
L(last_vec_x1):
#  if CHAR_PER_VEC != 64
L(first_vec_x1):
#  endif
	addq	$VEC_SIZE, %rdi
# endif
L(first_vec_x0):
	FIRST_VEC_X0 (64)

# ifndef USE_AS_STRNLEN
	.p2align 4,, 10
L(last_vec_x1):
L(first_vec_x1):
	FIRST_VEC_X1 (64)
# endif

# if !(defined USE_AS_STRNLEN)
	.p2align 4,, 10
#  if CHAR_PER_VEC == 64
L(first_vec_x2):
	FIRST_VEC_X2 (64)
#  else
L(first_vec_x3):
	FIRST_VEC_X3 (64)
#  endif
# endif

# ifdef USE_AS_STRNLEN
	/* Handle last 4x VEC after loop. All VECs have been loaded.  */
	.p2align 4,, 10
L(loop_len_end):
#  if CHAR_PER_VEC == 64
	movzbl	%al, %edx
#  else
#   ifndef USE_AS_WCSLEN
	leal	-1(%rsi, %rcx), %edx
#   endif
	andl	$(CHAR_PER_VEC * 4 - 1), %edx
#  endif

	kmovV	%k0, %VGPR(rcx)

#  if CHAR_PER_VEC != 64
	cmpb	$(CHAR_PER_VEC * 2), %dl
	jae	L(loop_len_end_more_2x)
#  else
	/* Save a bit of code size.  */
	testb	%dl, %dl
	js	L(loop_len_end_more_2x)
#  endif

	/* rcx has matches for first 2x VEC. If its zero we have no
	   remaining matches.  */
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(max_end_0)

	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %edx
#  if VEC_SIZE == 64
	jae	L(loop_len_end_mov_and_check)
#  else
	jb	L(max_end_0)
L(loop_len_end_mov_and_check):
	/* rax can't be zero here.  */
	mov	%VGPR(rcx), %VGPR(rax)
L(loop_len_end_check):
	LAST_VEC_CHECK_LOOP (max_end_0)
#  endif
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
#  if VEC_SIZE == 64
	jb	L(max_end_1)
L(loop_len_end_mov_and_check):
	/* rax can't be zero here.  */
	mov	%VGPR(rcx), %VGPR(rax)
L(loop_len_end_check):
	LAST_VEC_CHECK_LOOP (max_end_1)
#  else
	jae	L(loop_len_end_mov_and_check)
#  endif
L(max_end_1):
	movq	%rsi, %rax
	ret

	.p2align 4,, 8
L(loop_len_end_1x_or_2x):
	VPTESTN	%VEC(1), %VEC(1), %k1
	kmovV	%k1, %VGPR(rax)
#  if CHAR_PER_VEC == 64
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x0)

	mov	%VGPR(rcx), %VGPR(rax)
	subl	$CHAR_PER_VEC, %edx
L(last_vec_x0):
#  else
	salq	$CHAR_PER_VEC, %rcx
	orq	%rcx, %rax
#  endif
	bsfq	%rax, %rax
	/* Since we near end of maxlen, compute result by subtracting
	   position of null-term from maxlen.  */
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
	kmovV	%k0, %VGPR(r8)
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
	andl	$(CHAR_PER_VEC - 1), %eax
#  endif
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
# else

	kmovV	%k0, %VGPR(rax)
#  ifdef USE_AS_WCSLEN
	movl	%ecx, %edx
	shrl	$2, %edx
	andl	$(CHAR_PER_VEC - 1), %edx
	shrx	%edx, %eax, %eax
	testl	%eax, %eax
#  else
	shr	%cl, %VGPR(rax)
#  endif
	jz	L(cross_page_continue)
	bsf	%VGPR(rax), %VGPR(rax)
# endif
	ret

END(STRLEN)
#endif
