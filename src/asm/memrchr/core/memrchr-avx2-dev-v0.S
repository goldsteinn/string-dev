/* memrchr optimized with AVX2.
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

# ifndef MEMRCHR
#  define MEMRCHR	__memrchr_avx2
# endif

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

// abf-off
# ifndef SECTION
#	define SECTION(p) p##.avx
# endif
// abf-on

# define PAGE_SIZE	4096
# define VEC_SIZE	32

	.section SECTION(.text), "ax", @progbits
ENTRY(MEMRCHR)
# ifdef __ILP32__
	/* Clear upper bits.  */
	and	%RDX_LP, %RDX_LP
# else
	test	%RDX_LP, %RDX_LP
# endif
	jz	L(zero_0)

	vmovd	%esi, %xmm0
	/* Get end pointer.  */
	leaq	(%rdx, %rdi), %rax

	vpbroadcastb %xmm0, %ymm0

	/* Check if we can load 1x VEC without cross a page.  */
	testl	$(PAGE_SIZE - VEC_SIZE), %eax
	jz	L(page_cross)

	vpcmpeqb -(VEC_SIZE)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx
	cmpq	$VEC_SIZE, %rdx
	ja	L(more_1x_vec)

L(ret_vec_x0_test):
    shrxl   %edx, %ecx, %ecx
    vzeroupper
    bsrl    %ecx, %ecx
	jz	L(zero_0)
	subq	%rcx, %rax
	ret
L(zero_0):
	xorl	%eax, %eax
	ret

	.p2align 4,, 9
L(ret_vec_x0):
	lzcntl	%ecx, %ecx
	subq	%rcx, %rax
	VZEROUPPER_RETURN

	.p2align 4,, 10
L(more_1x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x0)
	andq	$-VEC_SIZE, %rax


	/* Need this comparison next no matter what.  */
L(last_4x_vec):
	vpcmpeqb -(VEC_SIZE)(%rax), %ymm0, %ymm1
L(last_4x_vec_loop):
	movq	%rax, %rdx
	decq	%rax
	subq	%rdi, %rdx
	vpmovmskb %ymm1, %ecx
	/* Fall through for short (hotter than length).  */
	cmpq	$(VEC_SIZE * 2), %rdx
	ja	L(more_2x_vec)
	cmpl	$VEC_SIZE, %edx
	jbe	L(ret_vec_x0_test)

	testl	%ecx, %ecx
	jnz	L(ret_vec_x0)

	vpcmpeqb -(VEC_SIZE * 2 - 1)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx
	/* This will naturally add 32 to position.  */
	lzcntq	%rcx, %rcx
	vzeroupper
	cmpl	%ecx, %edx
	jle	L(zero_0)
	subq	%rcx, %rax
	ret
	/* Inexpensive place to put this regarding code size / target
	   alignments.  */
L(page_cross):
	movq	%rax, %rsi
	andq	$-VEC_SIZE, %rsi
	vpcmpeqb (%rsi), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx
	movl	%eax, %r8d
	notl	%r8d
	shlxl	%r8d, %ecx, %ecx
	cmpq	%rdi, %rsi
	ja	L(more_1x_vec)
	lzcntl	%ecx, %ecx
	vzeroupper
	cmpl	%ecx, %edx
	jle	L(zero_0)
	subq	%rcx, %rax
	ret

	.p2align 4,, 11
L(ret_vec_x1):
	/* This will naturally add 32 to position.  */
	lzcntq	%rcx, %rcx
	subq	%rcx, %rax
	VZEROUPPER_RETURN


	.p2align 4,, 10
L(more_2x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x0)

	vpcmpeqb -(VEC_SIZE * 2 - 1)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)


	/* Needed no matter what.  */
	vpcmpeqb -(VEC_SIZE * 3 - 1)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx

	cmpq	$(VEC_SIZE * 4), %rdx
	ja	L(more_4x_vec)


	cmpl	$(VEC_SIZE * 3), %edx
	jle	L(ret_vec_x2_test)

	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)

	/* Needed no matter what.  */
	vpcmpeqb -(VEC_SIZE * 4 - 1)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx
	lzcntl	%ecx, %ecx
	subq	$(VEC_SIZE * 3), %rax
	vzeroupper
	subq	%rcx, %rax
	cmpq	%rax, %rdi
	ja	L(zero_2)
	ret

L(zero_2):
	xorl	%eax, %eax
	ret

	.p2align 4,, 4
L(ret_vec_x2_test):
	lzcntl	%ecx, %ecx
	subq	$(VEC_SIZE * 2), %rax
	vzeroupper
	subq	%rcx, %rax
	cmpq	%rax, %rdi
	ja	L(zero_2)
	ret


	.p2align 4,, 11
L(ret_vec_x2):
	/* ecx must be non-zero.  */
	bsrl	%ecx, %ecx
	leaq	(VEC_SIZE * -3 + 1)(%rcx, %rax), %rax
	VZEROUPPER_RETURN

	.p2align 4,, 14
L(ret_vec_x3):
	/* ecx must be non-zero.  */
	bsrl	%ecx, %ecx
	leaq	(VEC_SIZE * -4 + 1)(%rcx, %rax), %rax
	VZEROUPPER_RETURN



	.p2align 4
L(more_4x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)

	vpcmpeqb -(VEC_SIZE * 4 - 1)(%rax), %ymm0, %ymm1
	vpmovmskb %ymm1, %ecx

	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	cmpq	$(VEC_SIZE * 8), %rdx
	jbe	L(last_4x_vec)



	andq	$(VEC_SIZE * -4), %rax
	leaq	(VEC_SIZE * 4)(%rdi), %rdx

	.p2align 4
L(loop_4x_vec):
	/* Need this comparison next no matter what.  */
	vpcmpeqb -(VEC_SIZE)(%rax), %ymm0, %ymm1
	cmpq	%rdx, %rax
	jbe	L(last_4x_vec_loop)

	vpcmpeqb -(VEC_SIZE * 2)(%rax), %ymm0, %ymm2
	vpcmpeqb -(VEC_SIZE * 3)(%rax), %ymm0, %ymm3
	vpcmpeqb -(VEC_SIZE * 4)(%rax), %ymm0, %ymm4

	vpor	%ymm1, %ymm2, %ymm2
	vpor	%ymm3, %ymm4, %ymm4
	vpor	%ymm2, %ymm4, %ymm4
	vpmovmskb %ymm4, %esi

	addq	$(VEC_SIZE * -4), %rax

	testl	%esi, %esi
	jz	L(loop_4x_vec)


	vpmovmskb %ymm1, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x0_end)

	vpmovmskb %ymm2, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1_end)

	vpmovmskb %ymm3, %ecx
	salq	$32, %rcx
	orq	%rcx, %rsi
	bsrq	%rsi, %rsi

	addq	%rsi, %rax
	VZEROUPPER_RETURN

	.p2align 4
L(ret_vec_x0_end):
	bsrl	%ecx, %ecx
	leaq	(VEC_SIZE * 3)(%rcx, %rax), %rax
	VZEROUPPER_RETURN

	.p2align 4
L(ret_vec_x1_end):
	bsrl	%ecx, %ecx
	leaq	(VEC_SIZE * 2)(%rcx, %rax), %rax
	VZEROUPPER_RETURN
	/* 4 bytes until next cache line.  */
END(MEMRCHR)
#endif
