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
//#define USE_AS_STRNLEN
#if ISA_SHOULD_BUILD (3)


# ifndef STRLEN
#  define STRLEN	__strlen_avx2
# endif

# ifdef USE_AS_WCSLEN
#  define VPCMPEQ	vpcmpeqd
#  define VPMINU	vpminud
#  define CHAR_SIZE	4
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPMINU	vpminub
#  define CHAR_SIZE	1
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
	movq	%rdi, %rdx
	/* Check if we may cross page boundary with one vector load.  */
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes.  */
	VPCMPEQ	(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
# ifdef USE_AS_STRNLEN
	/* If length < VEC_SIZE handle special.  */
	cmpq	$CHAR_PER_VEC, %rsi
	jbe	L(first_vec_x0)
# endif
	/* If empty continue to aligned_more. Otherwise return bit
	   position of first match.  */
	testl	%eax, %eax
	jz	L(aligned_more)
	bsfl	%eax, %eax
# ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
# endif
L(return_vzeroupper):
	ZERO_UPPER_VEC_REGISTERS_RETURN

# ifdef USE_AS_STRNLEN
L(zero):
	xorl	%eax, %eax
	ret

	.p2align 4
L(first_vec_x0):
	/* Set bit for max len so that bsf will return min of max len
	   and position of first match.  */
#  ifdef USE_AS_WCSLEN
	/* NB: Multiply length by 4 to get byte count.  */
	sall	$2, %esi
#  endif
	btsq	%rsi, %rax
	tzcntl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
	VZEROUPPER_RETURN



	.p2align 4
L(aligned_more):
	/* Align data to VEC_SIZE - 1. This is the same number of
	   instructions as using andq with -VEC_SIZE but saves 4 bytes
	   of code on the x4 check.  */
	orq	$(VEC_SIZE - 1), %rdi
L(cross_page_continue):
#  ifdef USE_AS_STRNLEN
	movq	%rsi, %r8
#   ifdef USE_AS_WCSLEN
	leal	1(%rdi), %ecx
	subl	%edx, %ecx
	shrl	$2, %ecx
	subq	%rcx, %rsi
#   else
	subq	%rdi, %rsi
	leaq	-1(%rdx, %rsi), %rsi
#   endif
#  endif


	/* Load first VEC regardless.  */
	VPCMPEQ	1(%rdi), %ymm0, %ymm1
L(last_4x_vec_or_less):
	vpmovmskb %ymm1, %eax

	cmpq	$(CHAR_PER_VEC * 2), %rsi
	ja	L(more_2x_vec)

L(last_2x_vec_or_less):
	testl	%eax, %eax
	jnz	L(last_vec_x1_check)

	subl	$CHAR_PER_VEC, %esi
	jbe	L(max)

	VPCMPEQ	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
L(last_vec_x1_check):
	tzcntl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
	subq	%rsi, %rax
	jae	L(max)
	addq	%r8, %rax
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x2):
	bsfl	%eax, %eax
	subq	%rdx, %rdi
	leaq	(VEC_SIZE * 1 + 1)(%rdi, %rax), %rax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
#  endif
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x1):
	bsfl	%eax, %eax
	/* Safe to use 32 bit instructions as these are only called for
	   size = [1, 159].  */
	subq	%rdx, %rdi
	incq	%rdi
	addq	%rdi, %rax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
#  endif
	VZEROUPPER_RETURN


	.p2align 4,, 7
L(last_4x_vec_or_less_3):
	subq	$(VEC_SIZE * -4), %rdi
L(last_4x_vec_or_less_2):
	subl	$(CHAR_PER_VEC * -4), %esi
	VPCMPEQ	(1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	cmpl	$(CHAR_PER_VEC * 2), %esi
	jbe	L(last_2x_vec_or_less)

	.p2align 4,, 6
L(more_2x_vec):
	testl	%eax, %eax
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 1 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x2)

	cmpq	$(CHAR_PER_VEC * 4), %rsi
	ja	L(more_4x_vec)

	VPCMPEQ	(VEC_SIZE * 2 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x3_check)

	subl	$(CHAR_PER_VEC * 3), %esi
	jbe	L(max)

	VPCMPEQ	(VEC_SIZE * 3 + 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	tzcntl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
	subq	%rsi, %rax
	jae	L(max)
	addq	%r8, %rax
	VZEROUPPER_RETURN

L(max):
	movq	%r8, %rax
	VZEROUPPER_RETURN


	.p2align 4,, 10
L(first_vec_x3_check):
	bsfl	%eax, %eax
	subl	$(CHAR_PER_VEC * 2), %esi
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
	/* Check the end of data.  */
	cmpl	%eax, %esi
	jb	L(max)
	subq	%rdx, %rdi
	addq	$(VEC_SIZE * 2 + 1), %rdi
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rdi
#  endif
	addq	%rdi, %rax

	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x3):
	bsfl	%eax, %eax
	subq	%rdx, %rdi
	addq	$(VEC_SIZE * 2 + 1), %rdi
	addq	%rdi, %rax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
#  endif
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x4):
	bsfl	%eax, %eax
	subq	%rdx, %rdi
	leaq	(VEC_SIZE * 3 + 1)(%rdi, %rax), %rax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrq	$2, %rax
#  endif
	VZEROUPPER_RETURN


	.p2align 4,, 10
L(more_4x_vec):
# else

	.p2align 4
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

	.p2align 4
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

	.p2align 4
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

	.p2align 4
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
	subq	$(CHAR_PER_VEC * 8), %rsi
	jbe	L(last_4x_vec_or_less_3)
# endif
	incq	%rdi
	orq	$(VEC_SIZE * 4 - 1), %rdi
# ifdef USE_AS_STRNLEN
#  ifdef USE_AS_WCSLEN
	leaq	-1(%rdx), %rcx
	subq	%rdi, %rcx
	sarq	$2, %rcx
	leaq	(%r8, %rcx), %rsi
#  else
	leaq	-1(%rdx, %r8), %rsi
	subq	%rdi, %rsi
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

	subq	$-(VEC_SIZE * 4), %rdi
# ifdef USE_AS_STRNLEN
	/* Break if at end of length.  */
	subq	$(CHAR_PER_VEC * 4), %rsi
	jbe	L(loop_len_end)
# endif


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
	.p2align 5
L(loop_len_end):
	testl	%ecx, %ecx
	jz	L(max_end)

	VPCMPEQ	%ymm1, %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	subl	$(CHAR_PER_VEC * -2), %esi
	jg	L(loop_len_end_more_2x)

	subl	$(CHAR_PER_VEC * -2), %esi
	testl	%eax, %eax
	jnz	L(loop_len_end_check)

	subl	$(CHAR_PER_VEC * 1), %esi
	jle	L(max_end)

	VPCMPEQ	%ymm2, %ymm0, %ymm2
	vpmovmskb %ymm2, %eax
L(loop_len_end_check):
	tzcntl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif    
	subq	%rsi, %rax
	jae	L(max_end)
	addq	%r8, %rax
	VZEROUPPER_RETURN

L(max_end):
	movq	%r8, %rax
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(loop_len_end_more_2x):
	subq	%rdx, %rdi
	testl	%eax, %eax
	jnz	L(last_vec_return_x0)

	VPCMPEQ	%ymm2, %ymm0, %ymm2
	vpmovmskb %ymm2, %eax
	testl	%eax, %eax
	jnz	L(last_vec_return_x1)

	VPCMPEQ	%ymm3, %ymm0, %ymm3
	vpmovmskb %ymm3, %eax
	testl	%eax, %eax
	jnz	L(loop_len_end_check)

	movl	%ecx, %eax
	subl	$(CHAR_PER_VEC * 1), %esi
	jg	L(loop_len_end_check)
	movq	%r8, %rax
	VZEROUPPER_RETURN


# endif

	/* Cold case for crossing page with first load.  */
	.p2align 4,, 8
L(cross_page_boundary):
	/* Align data to VEC_SIZE - 1.  */
	orq	$(VEC_SIZE - 1), %rdi
	VPCMPEQ	-(VEC_SIZE - 1)(%rdi), %ymm0, %ymm1
	vpmovmskb %ymm1, %eax
	/* Remove the leading bytes. sarxl only uses bits [5:0] of COUNT
	   so no need to manually mod rdx.  */
	sarxl	%edx, %eax, %eax
# ifdef USE_AS_STRNLEN
	testl	%eax, %eax
	jnz	L(cross_page_less_vec)
	leaq	1(%rdi), %rcx
	subq	%rdx, %rcx
#  ifdef USE_AS_WCSLEN
	/* NB: Divide bytes by 4 to get wchar_t count.  */
	shrl	$2, %ecx
#  endif
	/* Check length.  */
	cmpq	%rsi, %rcx
	jb	L(cross_page_continue)
	movl	%esi, %eax
# else
	testl	%eax, %eax
	jz	L(cross_page_continue)
	bsfl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	/* NB: Divide length by 4 to get wchar_t count.  */
	shrl	$2, %eax
#  endif
# endif
	VZEROUPPER_RETURN

# ifdef USE_AS_STRNLEN
	.p2align 4,, 8
L(cross_page_less_vec):
	bsfl	%eax, %eax
#  ifdef USE_AS_WCSLEN
	shrl	$2, %eax
#  endif
	cmpq	%rax, %rsi
	cmovb	%esi, %eax
	VZEROUPPER_RETURN
# endif

END(STRLEN)
#endif
