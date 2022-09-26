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

#ifndef STRLEN
# define STRLEN	slen
#endif
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex512-vecs.h"
#endif

#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# ifndef STRLEN
#  error "NO strlen"
# endif


# ifdef USE_AS_WCSLEN
#  define VPCMP	vpcmpd
#  define VPTESTN	vptestnmd
#  define VPMINU	vpminud
#  define SHIFT_REG	VGPR(rcx)
#  define CHAR_SIZE	4
# else
#  define VPCMP	vpcmpb
#  define VPTESTN	vptestnmb
#  define VPMINU	vpminub
#  define SHIFT_REG	VGPR(rdx)
#  define CHAR_SIZE	1
# endif




# define XZERO	VEC_xmm(0)
# define VZERO	VEC(0)

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

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
	mov	%RSI_LP, %R8_LP
# endif

	vpxorq	%XZERO, %XZERO, %XZERO
	/* Check the first VEC_SIZE bytes.  Each bit in K0 represents a
	   null byte.  */
	VPCMP	$0, (%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)

	shrx	%VGPR(rdx), %VGPR(rax), %VGPR(rax)

	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
	tzcnt	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_STRNLEN
	cmpq	%rax, %rsi
	cmovb	%rsi, %rax
# endif
	ret

# ifdef USE_AS_STRNLEN
L(zero):
	xorl	%eax, %eax
	ret
# endif

	.p2align 4
L(first_vec_x1):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, VEC_SIZE * 5 - 1].  */
# ifdef USE_AS_STRNLEN
	/* Use ecx which was computed earlier to compute correct value.
	 */
	leal	-(CHAR_PER_VEC * 4 + 1)(%rcx, %rax), %eax
# else
	subl	%edx, %edi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
#  endif
	leal	CHAR_PER_VEC(%rdi, %rax), %eax
# endif
	ret

	.p2align 4
L(first_vec_x2):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, VEC_SIZE * 5 - 1].  */
# ifdef USE_AS_STRNLEN
	/* Use ecx which was computed earlier to compute correct value.
	 */
	leal	-(CHAR_PER_VEC * 3 + 1)(%rcx, %rax), %eax
# else
	subl	%edx, %edi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
#  endif
	leal	(CHAR_PER_VEC * 2)(%rdi, %rax), %eax
# endif
	ret

	.p2align 4
L(first_vec_x3):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, VEC_SIZE * 5 - 1].  */
# ifdef USE_AS_STRNLEN
	/* Use ecx which was computed earlier to compute correct value.
	 */
	leal	-(CHAR_PER_VEC * 2 + 1)(%rcx, %rax), %eax
# else
	subl	%edx, %edi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
#  endif
	leal	(CHAR_PER_VEC * 3)(%rdi, %rax), %eax
# endif
	ret

	.p2align 4
L(first_vec_x4):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, VEC_SIZE * 5 - 1].  */
# ifdef USE_AS_STRNLEN
	/* Use ecx which was computed earlier to compute correct value.
	 */
	leal	-(CHAR_PER_VEC + 1)(%rcx, %rax), %eax
# else
	subl	%edx, %edi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %edi
#  endif
	leal	(CHAR_PER_VEC * 4)(%rdi, %rax), %eax
# endif
	ret

	.p2align 5
L(aligned_more):
	/* Check the first 4 * VEC_SIZE.  Only one VEC_SIZE at a time
	   since data is only aligned to VEC_SIZE.  */
# ifdef USE_AS_STRNLEN
	/* + CHAR_SIZE because it simplies the logic in
	   last_4x_vec_or_less.  */
	leaq	(VEC_SIZE * 5 + CHAR_SIZE)(%rdi), %rcx
	subq	%rdx, %rcx
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %ecx
#  endif
# endif
	/* Load first VEC regardless.  */
	VPCMP	$0, VEC_SIZE(%rdi), %VZERO, %k0
# ifdef USE_AS_STRNLEN
	/* Adjust length. If near end handle specially.  */
	subq	%rcx, %rsi
	jb	L(last_4x_vec_or_less)
# endif
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMP	$0, (VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	VPCMP	$0, (VEC_SIZE * 3)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VPCMP	$0, (VEC_SIZE * 4)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x4)

	addq	$VEC_SIZE, %rdi
# ifdef USE_AS_STRNLEN
	/* Check if at last VEC_SIZE * 4 length.  */
	cmpq	$(CHAR_PER_VEC * 4 - 1), %rsi
	jbe	L(last_4x_vec_or_less_load)
	movl	%edi, %ecx
	andl	$(VEC_SIZE * 4 - 1), %ecx
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarl	$2, %ecx
#  endif
	/* Readjust length.  */
	addq	%rcx, %rsi
# endif
	/* Align data to VEC_SIZE * 4.  */
	andq	$-(VEC_SIZE * 4), %rdi

	/* Compare 4 * VEC at a time forward.  */
	.p2align 4
L(loop_4x_vec):
	/* Load first VEC regardless.  */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
# ifdef USE_AS_STRNLEN
	/* Break if at end of length.  */
	subq	$(CHAR_PER_VEC * 4), %rsi
	jb	L(last_4x_vec_or_less_cmpeq)
# endif
	/* Save some code size by microfusing VPMINU with the load.
	   Since the matches in ymm2/ymm4 can only be returned if there
	   where no matches in ymm1/ymm3 respectively there is no issue
	   with overlap.  */
	VPMINU	(VEC_SIZE * 5)(%rdi), %VEC(1), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VPMINU	(VEC_SIZE * 7)(%rdi), %VEC(3), %VEC(4)

	VPTESTN	%VEC(2), %VEC(2), %k0
	VPTESTN	%VEC(4), %VEC(4), %k1
	subq	$-(VEC_SIZE * 4), %rdi
	Vkortest %k0, %k1
	jz	L(loop_4x_vec)


	/* Check if end was in first half.  */
	Vkmov	%k0, %VGPR(rcx)

	subq	%rdx, %rdi
# ifdef USE_AS_WCSLEN
	shrq	$2, %rdi
# endif
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(second_vec_return)

	VPCMP	$0, %VEC(1), %VZERO, %k2
	Vkmov	%k2, %VGPR(rax)
	/* Combine VEC1 matches (edx) with VEC2 matches (eax).  */

# if (defined USE_AS_WCSLEN) || VEC_SIZE == 32
#  ifdef USE_AS_WCSLEN
	sall	$CHAR_PER_VEC, %ecx
	orl	%ecx, %eax
	tzcntl	%eax, %eax
#  elif VEC_SIZE == 32
	salq	$CHAR_PER_VEC, %rcx
	orq	%rcx, %rax
	tzcntq	%rax, %rax
#  endif
	addq	%rdi, %rax
	ret
# else
	testq	%rax, %rax
	jnz	L(last_vec_x1_strlen)
	tzcntq	%rcx, %rcx
	leaq	CHAR_PER_VEC(%rdi, %rcx), %rax
	ret

#  ifndef USE_AS_STRNLEN
	.p2align 4,, 7
L(last_vec_x1_strlen):
	tzcnt	%VGPR(rax), %VGPR(rax)
	addq	%rdi, %rax
	ret
#  endif
# endif




# ifdef USE_AS_STRNLEN

L(last_4x_vec_or_less_load):
	/* Depending on entry adjust rdi / prepare first VEC in VEC(1).
	 */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
L(last_4x_vec_or_less_cmpeq):
	VPCMP	$0, %VEC(1), %VZERO, %k0
	addq	$(VEC_SIZE * 3), %rdi
L(last_4x_vec_or_less):
	Vkmov	%k0, %VGPR(rax)
	/* If remaining length > VEC_SIZE * 2. This works if esi is off
	   by VEC_SIZE * 4.  */
#  if VEC_SIZE == 64
	testb	%sil, %sil
	js	L(last_4x_vec)
#  else
	testl	$(CHAR_PER_VEC * 2), %esi
	jnz	L(last_4x_vec)
#  endif


	/* length may have been negative or positive by an offset of
	   CHAR_PER_VEC * 4 depending on where this was called from.
	   This fixes that.  */
#  if VEC_SIZE == 64
	// #   warning "Make dst != src for move-elimination"
	movzbl	%sil, %esi
#  else
	andl	$(CHAR_PER_VEC * 4 - 1), %esi
#  endif

	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x1_check)

	/* Check the end of data.  */
	subl	$CHAR_PER_VEC, %esi
	jb	L(max)

	VPCMP	$0, (VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	cmpl	%eax, %esi
	jb	L(max)

	subq	%rdx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
L(max):
	movq	%r8, %rax
	ret
# endif

	/* Placed here in strnlen so that the jcc L(last_4x_vec_or_less)
	   in the 4x VEC loop can use 2 byte encoding.  */
	.p2align 4
L(second_vec_return):
	VPCMP	$0, %VEC(3), %VZERO, %k0
	/* Combine VEC(3) matches (k0) with VEC(4) matches (k1).  */
# if (defined USE_AS_WCSLEN) || VEC_SIZE == 32
#  ifdef USE_AS_WCSLEN
#   if VEC_SIZE == 32
	kunpckwd %k0, %k1, %k0
#   else
	kunpckbw %k0, %k1, %k0
#   endif
	kmovd	%k0, %eax
	tzcntl	%eax, %eax
#  else
	kunpckdq %k0, %k1, %k0
	kmovq	%k0, %rax
	tzcntq	%rax, %rax
#  endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
# else
	kmovq	%k0, %rax
	testq	%rax, %rax
	jnz	L(last_vec_x2_strlen)
	kmovq	%k1, %rcx
	tzcntq	%rcx, %rcx
	leaq	(CHAR_PER_VEC * 3)(%rdi, %rcx), %rax
	ret

#  ifndef USE_AS_STRNLEN
	.p2align 4,, 9
L(last_vec_x2_strlen):
	tzcnt	%VGPR(rax), %VGPR(rax)
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret
#  endif

# endif



# ifdef USE_AS_STRNLEN
L(last_vec_x1_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	cmpl	%eax, %esi
	jb	L(max)
	subq	%rdx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC)(%rdi, %rax), %rax
	ret

	.p2align 4
L(last_4x_vec):
	/* Test first 2x VEC normally.  */
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x1)

	VPCMP	$0, (VEC_SIZE * 2)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x2)

	/* Normalize length.  */
	andl	$(CHAR_PER_VEC * 4 - 1), %esi
	VPCMP	$0, (VEC_SIZE * 3)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x3)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC * 3), %esi
	jb	L(max)

	VPCMP	$0, (VEC_SIZE * 4)(%rdi), %VZERO, %k0
	Vkmov	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	/* Check the end of data.  */
	cmpl	%eax, %esi
	jb	L(max_end)

	subq	%rdx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 4)(%rdi, %rax), %rax
	ret

	.p2align 4
L(last_vec_x1):
#  if !(defined USE_AS_WCSNLEN || VEC_SIZE == 32)
	subq	%rdx, %rdi
L(last_vec_x1_strlen):
#  endif
	tzcnt	%VGPR(rax), %VGPR(rax)
#  if (defined USE_AS_WCSNLEN || VEC_SIZE == 32)
	subq	%rdx, %rdi
#   ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#   endif
#  endif
	leaq	(CHAR_PER_VEC)(%rdi, %rax), %rax
	ret

	.p2align 4
L(last_vec_x2):
#  if !(defined USE_AS_WCSNLEN || VEC_SIZE == 32)
	subq	%rdx, %rdi
#  endif
L(last_vec_x2_strlen):
	tzcnt	%VGPR(rax), %VGPR(rax)
#  if defined USE_AS_WCSNLEN || VEC_SIZE == 32
	subq	%rdx, %rdi
#   ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#   endif
#  endif
	leaq	(CHAR_PER_VEC * 2)(%rdi, %rax), %rax
	ret

	.p2align 4
L(last_vec_x3):
	tzcnt	%VGPR(rax), %VGPR(rax)
	subl	$(CHAR_PER_VEC * 2), %esi
	/* Check the end of data.  */
	cmpl	%eax, %esi
	jb	L(max_end)
	subq	%rdx, %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get the wchar_t count.  */
	sarq	$2, %rdi
#  endif
	leaq	(CHAR_PER_VEC * 3)(%rdi, %rax), %rax
	ret
L(max_end):
	movq	%r8, %rax
	ret
# endif
L(page_cross):
END(STRLEN)
#endif
