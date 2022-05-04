/* strrchr/wcsrchr optimized with AVX2.
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
#if IS_IN (libc)

# ifndef STRRCHR
#  define STRRCHR	__strrchr_avx2
# endif

# ifdef USE_AS_WCSRCHR
#  define CHAR_SIZE	4
#  define SHIFT_REG	esi
#  define VPBROADCAST	vpbroadcastd
#  define VPCMPEQ	vpcmpeqd
# else
#  define CHAR_SIZE	1
#  define SHIFT_REG	edi
#  define VPBROADCAST	vpbroadcastb
#  define VPCMPEQ	vpcmpeqb
# endif

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

// abf-off
# ifndef SECTION
#	define SECTION(p) p##.avx
# endif
// abf-on

# define VEC_SIZE	32
# define PAGE_SIZE	4096
	.section SECTION(.text), "ax", @progbits
ENTRY(STRRCHR)
	movd	%esi, %xmm7
	movl	%edi, %eax
	/* Broadcast CHAR to YMM4.  */
	VPBROADCAST %xmm7, %ymm7
	vpxor	%xmm0, %xmm0, %xmm0

	// andl    $(PAGE_SIZE - 1), %eax
	sall	$20, %eax
	cmpl	$((PAGE_SIZE - VEC_SIZE) << 20), %eax
	ja	L(cross_page)

L(page_cross_continue):
	vmovdqu	(%rdi), %ymm1
	VPCMPEQ	%ymm1, %ymm0, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jz	L(aligned_more)

	VPCMPEQ	%ymm1, %ymm7, %ymm1
	vpmovmskb %ymm1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(ret0)
	bsrl	%eax, %eax
	addq	%rdi, %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
L(ret0):
L(return_vzeroupper):
	ZERO_UPPER_VEC_REGISTERS_RETURN

	.p2align 4,, 10
L(first_vec_x1):
	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(first_vec_x1_return)

	.p2align 4,, 4
L(first_vec_x0_test):
	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %eax
	testl	%eax, %eax
	jz	L(ret1)
	bsrl	%eax, %eax
	addq	%r8, %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
L(ret1):
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(first_vec_x0_x1_test):
	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %eax
	testl	%eax, %eax
	jz	L(first_vec_x0_test)
	.p2align 4,, 4
L(first_vec_x1_return):
	bsrl	%eax, %eax

	leaq	(1)(%rdi, %rax), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
	VZEROUPPER_RETURN


	.p2align 4,, 10
L(first_vec_x2):
	VPCMPEQ	%ymm3, %ymm7, %ymm6
	vpmovmskb %ymm6, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x0_x1_test)
	bsrl	%eax, %eax
	leaq	(VEC_SIZE + 1)(%rdi, %rax), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
	VZEROUPPER_RETURN


	.p2align 4
L(aligned_more):
	movq	%rdi, %r8
	orq	$(VEC_SIZE - 1), %rdi
	vmovdqu	1(%rdi), %ymm2
	VPCMPEQ	%ymm2, %ymm0, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x1)

	vmovdqu	(VEC_SIZE + 1)(%rdi), %ymm3
	VPCMPEQ	%ymm3, %ymm0, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x2)


	movq	%rdi, %rsi
	.p2align 4
L(first_aligned_loop):
	vmovdqu	(VEC_SIZE * 2 + 1)(%rdi), %ymm4
	VPCMPEQ	%ymm4, %ymm0, %ymm6
	VPCMPEQ	%ymm4, %ymm7, %ymm4
	vpor	%ymm6, %ymm4, %ymm5
	vpmovmskb %ymm5, %eax
	addq	$VEC_SIZE, %rdi
	testl	%eax, %eax
	jz	L(first_aligned_loop)
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jz	L(second_aligned_loop_prep)

	/* Search char could be zero so we need to get the true match.
	 */
	vpmovmskb %ymm4, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(first_aligned_loop_return)

	VPCMPEQ	%ymm3, %ymm7, %ymm3
	VPCMPEQ	%ymm2, %ymm7, %ymm2
	vpmovmskb %ymm3, %eax
	vpmovmskb %ymm2, %edx
	/* Use add for macro-fusion.  */
	addq	%rax, %rdx
	jz	L(first_vec_x0_test)
	/* NB: We could move this shift to before the branch and save a
	   bit of code size / performance on the fall through. The
	   branch leads to the null case which generally seems hotter
	   than char in first 3x VEC.  */
	salq	$32, %rax
	orq	%rdx, %rax
	bsrq	%rax, %rax
	leaq	(1)(%rsi, %rax), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(first_aligned_loop_return):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 1 + 1)(%rdi, %rax), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
	VZEROUPPER_RETURN

	/* Search char cannot be zero.  */
	.p2align 4
L(second_aligned_loop_set_furthest_match):
	movl	%edx, %eax
L(second_aligned_loop_prep):
	movq	%rdi, %rsi

	.p2align 4
L(second_aligned_loop):
	vmovdqu	(VEC_SIZE * 2 + 1)(%rdi), %ymm4
	VPCMPEQ	%ymm4, %ymm0, %ymm6
	VPCMPEQ	%ymm4, %ymm7, %ymm4
	vpor	%ymm6, %ymm4, %ymm5
	vpmovmskb %ymm5, %edx
	addq	$VEC_SIZE, %rdi
	testl	%edx, %edx
	jz	L(second_aligned_loop)
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jz	L(second_aligned_loop_set_furthest_match)

	subl	%ecx, %edx
	jnz	L(return_new_match)

L(return_old_match):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 1 + 1)(%rsi, %rax), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif    
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(return_new_match):
	decl	%ecx
	andl	%ecx, %edx
	jz	L(return_old_match)
	bsrl	%edx, %edx
	leaq	(VEC_SIZE * 1 + 1)(%rdi, %rdx), %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif    
	VZEROUPPER_RETURN

L(cross_page):
	movq	%rdi, %rsi
	andq	$-VEC_SIZE, %rsi
	vmovdqu	(%rsi), %ymm1
	VPCMPEQ	%ymm1, %ymm0, %ymm6
	vpmovmskb %ymm6, %ecx
	shrxl	%edi, %ecx, %ecx
	testl	%ecx, %ecx
	jz	L(page_cross_continue)
	VPCMPEQ	%ymm1, %ymm7, %ymm1
	vpmovmskb %ymm1, %eax
	shrxl	%edi, %eax, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(ret2)
	bsrl	%eax, %eax
	addq	%rdi, %rax
# ifdef USE_AS_WCSRCHR
	andq	$-CHAR_SIZE, %rax
# endif
L(ret2):
	VZEROUPPER_RETURN
END(STRRCHR)
#endif
