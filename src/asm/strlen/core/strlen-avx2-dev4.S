/* strlen/strnlen/wcslen/wcsnlen optimized with AVX2.
   Copyright (C) 2017-2022 Free Software Foundation, Inc.
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
	// #define USE_AS_WCSLEN
	// #define USE_AS_STRNLEN
#if ISA_SHOULD_BUILD (3)
	// # define USE_AS_STRNLEN

# ifndef STRLEN
#  define STRLEN	__strlen_avx2
# endif

# ifdef USE_AS_WCSLEN
#  define VPCMPEQ	vpcmpeqd
#  define VPMINU	vpminud
#  define CHAR_SIZE	4
#  define END_REG	ecx
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
#  define END_REG	r8d
# endif

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

# ifndef SECTION
#  define SECTION(p)	p##.avx
# endif

# define VEC_SIZE	32
# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# ifndef USE_AS_STRNLEN

# endif

	.section SECTION(.text), "ax", @progbits
ENTRY(STRLEN)
# ifdef USE_AS_STRNLEN
	/* Check zero length.  */
#  ifdef __ILP32__
	/* Clear upper bits.  */
	and	%RSI_LP, %RSI_LP
#  else
	test	%RSI_LP, %RSI_LP
#  endif
	jz	L(zero)
	/* Store max len in R8_LP before adjusting if using WCSLEN.  */
# endif
	movl	%edi, %eax
	vpxor	%xmm0, %xmm0, %xmm0
	/* Clear high bits from edi. Only keeping bits relevant to page
	   cross check.  */
	andl	$(PAGE_SIZE - 1), %eax
# ifndef USE_AS_STRNLEN
	movq	%rdi, %rdx
# endif
	/* Check if we may cross page boundary with one vector load.  */
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes.  */
	VPCMPEQ	(%rdi), %ymm0, %ymm1
# ifdef USE_AS_STRNLEN
#  if 1
	vpmovmskb %ymm1, %eax
	tzcnt	%eax, %eax
	jnc	L(less_1x_vec)
	cmpq	$CHAR_PER_VEC, %rsi
	ja	L(aligned_more)
L(less_1x_vec):
#   ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#   endif
	cmpq	%rax, %rsi
	cmovb	%esi, %eax
#  else
	vpmovmskb %ymm1, %ecx
	movq	%rsi, %rax
	bsf	%ecx, %eax
	cmpq	$VEC_SIZE, %rax
	ja	L(aligned_more)
	cmpq	%rax, %rsi
	cmovb	%esi, %eax
#  endif
# else
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jz	L(aligned_more)
	bsf	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
# endif
L(return_vzeroupper):
	ZERO_UPPER_VEC_REGISTERS_RETURN

# ifdef USE_AS_STRNLEN
	.p2align 4,, 8
L(aligned_more):
	movq	%rdi, %rdx
	/* Align data to VEC_SIZE - 1. This is the same number of
	   instructions as using andq with -VEC_SIZE but saves 4 bytes
	   of code on the x4 check.  */
	orq	$(VEC_SIZE - 1), %rdi
L(cross_page_continue):
#  ifdef USE_AS_STRNLEN
#   ifdef USE_AS_WCSLEN
	leaq	1(%rdx), %rcx
	subq	%rdi, %rcx
	sarq	$2, %rcx
	addq	%rsi, %rcx
#   else
	leaq	-1(%rdx, %rsi), %rcx
	subq	%rdi, %rcx
#   endif
#  endif


	/* Load first VEC regardless.  */
	VPCMPEQ	1(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax

	cmpq	$(CHAR_PER_VEC * 2), %rcx
	ja	L(more_2x_vec)

L(last_2x_vec_or_less):
	testl	%eax, %eax
	jnz	L(last_vec_check)

	subl	$CHAR_PER_VEC, %ecx
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(last_vec_check)
	.p2align 4,, 4
L(zero):
L(max_0):
	movl	%esi, %eax
	VZEROUPPER_RETURN


	.p2align 4
L(first_vec_x2):
	addl	$(VEC_SIZE), %edi
L(first_vec_x1):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	incl	%edi
	addl	%edi, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN


	.p2align 4,, 7
L(last_4x_vec_or_less):
	subq	$(VEC_SIZE * -4), %rdi
	addl	$(CHAR_PER_VEC * -4), %ecx
	VPCMPEQ	(1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	cmpl	$(CHAR_PER_VEC * 2), %ecx
	jbe	L(last_2x_vec_or_less)
	.p2align 4,, 6
L(more_2x_vec):
	testl	%eax, %eax
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 1 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x2)

	cmpq	$(CHAR_PER_VEC * 4), %rcx
	ja	L(more_4x_vec)

	VPCMPEQ	(VEC_SIZE * 2 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	subl	$(CHAR_PER_VEC * 2), %ecx
	testl	%eax, %eax
	jnz	L(last_vec_check)

	subl	$(CHAR_PER_VEC * 1), %ecx
	jbe	L(max_0)

	VPCMPEQ	(VEC_SIZE * 3 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	.p2align 4,, 3
L(last_vec_check):
	tzcntl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
	subl	%ecx, %eax
	jae	L(max_0)
	leal	(%rsi, %rax), %eax
	VZEROUPPER_RETURN
	.p2align 4,, 6
L(first_vec_x4):
	addl	$(VEC_SIZE), %edi
L(first_vec_x3):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	leal	(VEC_SIZE * 2 + 1)(%rdi, %rax), %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN




	.p2align 4,, 10
L(more_4x_vec):
# else

	.p2align 4,, 10
L(first_vec_x1):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	incl	%edi
	addl	%edi, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x2):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	addl	$(VEC_SIZE + 1), %edi
	addl	%edi, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x3):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	addl	$(VEC_SIZE * 2 + 1), %edi
	addl	%edi, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x4):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subl	%edx, %edi
	addl	$(VEC_SIZE * 3 + 1), %edi
	addl	%edi, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN

	.p2align 5,, 18
	.p2align 4,, 10
L(aligned_more):
	/* Align data to VEC_SIZE - 1. This is the same number of
	   instructions as using andq with -VEC_SIZE but saves 4 bytes
	   of code on the x4 check.  */
	orq	$(VEC_SIZE - 1), %rdi
L(cross_page_continue):
	VPCMPEQ	1(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x2)
# endif

	VPCMPEQ	(VEC_SIZE * 2 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 3 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x4)

# ifdef USE_AS_STRNLEN
	cmpq	$(CHAR_PER_VEC * 8), %rcx
	jbe	L(last_4x_vec_or_less)
# endif


	addq	$1, %rdi
	orq	$(VEC_SIZE * 4 - 1), %rdi
# ifdef USE_AS_STRNLEN
#  ifdef USE_AS_WCSLEN
	leaq	(1 - CHAR_SIZE)(%rdx), %rax
	subq	%rdi, %rax
	sarq	$2, %rax
	addq	%rsi, %rax
#  else
	leaq	-(1 + VEC_SIZE * 4)(%rdx, %rsi), %r8
	movl	%r8d, %eax
	orq	$(VEC_SIZE * 4 -1), %r8
#  endif
# endif
	/* Compare 4 * VEC at a time forward.  */
	.p2align 4
L(loop_4x_vec):
	/* Save some code size by microfusing VPMINU with the load.
	   Since the matches in ymm2/ymm4 can only be returned if there
	   where no matches in ymm1/ymm3 respectively there is no issue
	   with overlap.  */
	vmovdqa	1(%rdi), %ymm1
	VPMINU	(VEC_SIZE + 1)(%rdi), %ymm1, %ymm2
	vmovdqa	(VEC_SIZE * 2 + 1)(%rdi), %ymm3
	VPMINU	(VEC_SIZE * 3 + 1)(%rdi), %ymm3, %ymm4

	VPMINU	%ymm2, %ymm4, %ymm5
	VPCMPEQ	%ymm5, %ymm0, %ymm5
	vpmovmskb %ymm5, %ecx


# ifdef USE_AS_STRNLEN
	/* Break if at end of length.  */
#  ifdef USE_AS_WCSLEN
	subq	$(CHAR_PER_VEC * 4), %rax
	jb	L(loop_len_end)
#  else
	cmpq	%r8, %rdi
	je	L(loop_len_end)
#  endif
# endif

	subq	$-(VEC_SIZE * 4), %rdi
	testl	%ecx, %ecx
	jz	L(loop_4x_vec)


	VPCMPEQ	%ymm1, %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	subq	%rdx, %rdi
	testl	%eax, %eax
	jnz	L(last_vec_return_x0)

	VPCMPEQ	%ymm2, %ymm0, %ymm2
	vpmovmskb %ymm2, %eax
	testl	%eax, %eax
	jnz	L(last_vec_return_x1)

	/* Combine last 2 VEC.  */
	VPCMPEQ	%ymm3, %ymm0, %ymm3
	vpmovmskb %ymm3, %eax
	/* rcx has combined result from all 4 VEC. It will only be used
	   if the first 3 other VEC all did not contain a match.  */
	salq	$32, %rcx
	orq	%rcx, %rax
	bsfq	%rax, %rax
	subq	$(VEC_SIZE * 2 - 1), %rdi
	addq	%rdi, %rax
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
# endif
	VZEROUPPER_RETURN

	.p2align 4,, 10

L(last_vec_return_x0):
	bsfl	%eax, %eax
	subq	$(VEC_SIZE * 4 - 1), %rdi
	addq	%rdi, %rax
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
# endif
	VZEROUPPER_RETURN


	.p2align 4,, 10

L(last_vec_return_x1):
	bsfl	%eax, %eax
	subq	$(VEC_SIZE * 3 - 1), %rdi
	addq	%rdi, %rax
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
# endif
	VZEROUPPER_RETURN

# ifdef USE_AS_STRNLEN

	.p2align 4,, 10
L(loop_len_end):
	testl	%ecx, %ecx
	jz	L(max_end_0)

	andl	$(CHAR_PER_VEC * 4 - 1), %eax

	VPCMPEQ	%ymm1, %ymm0, %ymm1
	vpmovmskb %ymm1, %edx
	cmpl	$(CHAR_PER_VEC * 2), %eax
	jae	L(loop_len_end_more_2x)

	testl	%edx, %edx
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %eax
	jb	L(max_end_0)
	VPCMPEQ	%ymm2, %ymm0, %ymm2
	vpmovmskb %ymm2, %edx
	testl	%edx, %edx
	jnz	L(loop_len_end_check)
L(max_end_0):
	movq	%rsi, %rax
	VZEROUPPER_RETURN


	.p2align 4,, 12
L(loop_len_end_more_2x):
	testl	%edx, %edx
	jnz	L(last_vec_return_x0_end)

	VPCMPEQ	%ymm2, %ymm0, %ymm2
	vpmovmskb %ymm2, %edx
	testl	%edx, %edx
	jnz	L(last_vec_return_x1_end)

	VPCMPEQ	%ymm3, %ymm0, %ymm3
	vpmovmskb %ymm3, %edx
	subl	$(CHAR_PER_VEC * 2), %eax
	testl	%edx, %edx
	jnz	L(loop_len_end_check)

	movl	%ecx, %edx
	subl	$(CHAR_PER_VEC * 1), %eax
	jb	L(max_end_1)
L(loop_len_end_check):
	bsfl	%edx, %edx
#  ifdef USE_AS_WCSLEN
	shrl	$2, %edx
#  endif
	subq	%rax, %rdx
	ja	L(max_end_1)
	leaq	-1(%rsi, %rdx), %rax

	VZEROUPPER_RETURN

L(max_end_1):
	movq	%rsi, %rax
	VZEROUPPER_RETURN

L(last_vec_return_x1_end):
	subl	$CHAR_PER_VEC, %eax
L(last_vec_return_x0_end):
	bsfl	%edx, %edx
#  ifdef USE_AS_WCSLEN
	shrl	$2, %edx
#  endif
	subq	%rax, %rsi
	leaq	-1(%rsi, %rdx), %rax
	VZEROUPPER_RETURN


# endif

	/* Cold case for crossing page with first load.  */
	.p2align 4,, 8
L(cross_page_boundary):
	/* Align data to VEC_SIZE - 1.  */
# ifdef USE_AS_STRNLEN
	movq	%rdi, %rdx
# endif
	orq	$(VEC_SIZE - 1), %rdi
	VPCMPEQ	-(VEC_SIZE - 1)(%rdi), %ymm0, %ymm1
# ifdef USE_AS_STRNLEN
	vpmovmskb %ymm1, %END_REG
	/* Remove the leading bytes. sarxl only uses bits [5:0] of COUNT
	   so no need to manually mod rdx.  */

	sarxl	%eax, %END_REG, %END_REG
	negl	%eax
	andl	$(VEC_SIZE - 1), %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
	cmpq	%rax, %rsi
	jbe	L(cross_page_less_1x_vec)
	bsfl	%ecx, %eax
	jz	L(cross_page_continue)
	shrl	$2, %eax
	VZEROUPPER_RETURN
L(cross_page_less_1x_vec):
	tzcntl	%ecx, %eax
	shrl	$2, %eax
	cmpq	%rax, %rsi
	cmovb	%esi, %eax

#  else
	movq	%rsi, %rcx
	bsf	%r8d, %ecx
	cmpq	%rax, %rcx
	ja	L(cross_page_continue)
	movl	%ecx, %eax
	cmpq	%rcx, %rsi
	cmovb	%esi, %eax
#  endif
# else
	vpmovmskb %ymm1, %eax
	sarxl	%edx, %eax, %eax
	testl	%eax, %eax
	jz	L(cross_page_continue)
	bsfl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
# endif
	VZEROUPPER_RETURN

END(STRLEN)
#endif
