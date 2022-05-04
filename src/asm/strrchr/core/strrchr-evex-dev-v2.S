/* strrchr/wcsrchr optimized with 256-bit EVEX instructions.
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

#include "../../libc-asm-common.h"
#if IS_IN (libc)

# ifndef STRRCHR
#  define STRRCHR	__strrchr_evex
# endif

# define VMOVU	vmovdqu64
# define VMOVA	vmovdqa64

# ifdef USE_AS_WCSRCHR
#  define TESTEQ	subl $0xff,
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
#  define SHIFT_REG	r8d
# else
#  define TESTEQ	incl
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
#  define SHIFT_REG	ecx
# endif

# define XMMZERO	xmm16
# define YMMZERO	ymm16
# define YMMMATCH	ymm17
# define YMMSAVE	ymm18

# define YMM1	ymm19
# define YMM2	ymm20
# define YMM3	ymm21
# define YMM4	ymm22
# define YMM5	ymm23
# define YMM6	ymm24
# define YMM7	ymm25
# define YMM8	ymm26
# define YMM9	ymm27
# define YMM10	ymm28
# define YMM11	ymm29
# define YMM12	ymm30

# define VEC_SIZE	32
# define PAGE_SIZE	4096
	.section .text.evex, "ax", @progbits
ENTRY(STRRCHR)
	movl	%edi, %eax
	/* Broadcast CHAR to YMMMATCH.  */
	VPBROADCAST %esi, %YMMMATCH

	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	jg	L(cross_page_boundary)

L(page_cross_continue):
	VMOVU	(%rdi), %YMM1
	VPTESTN	%YMM1, %YMM1, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(aligned_more)
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(ret0)
	bsrl	%eax, %eax
	addq	%rdi, %rax
L(ret0):
	ret

	.p2align 4,, 6
L(first_vec_x1):
	VPCMP	$0, %YMMMATCH, %YMM2, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(first_vec_x1_return)
	.p2align 4,, 4
L(first_vec_x0_test):
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kmovd	%k1, %eax
	testl	%eax, %eax
	jz	L(ret1)
	bsrl	%eax, %eax
	addq	%rsi, %rax
L(ret1):
	ret

	.p2align 4,, 6
L(first_vec_x0_x1_test):
	VPCMP	$0, %YMMMATCH, %YMM2, %k1
	kmovd	%k1, %eax
	testl	%eax, %eax
	jz	L(first_vec_x0_test)
	.p2align 4,, 4
L(first_vec_x1_return):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE)(%rdi, %rax), %rax
	ret

	.p2align 4,, 10
L(first_vec_x2):
	VPCMP	$0, %YMMMATCH, %YMM3, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x0_x1_test)
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 2)(%rdi, %rax), %rax
	ret

	.p2align 4
L(aligned_more):
	/* Need to keep original pointer incase YMM1 has last match.  */
	movq	%rdi, %rsi
	andq	$-VEC_SIZE, %rdi
	VMOVU	VEC_SIZE(%rdi), %YMM2
	VPTESTN	%YMM2, %YMM2, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x1)

	VMOVU	(VEC_SIZE * 2)(%rdi), %YMM3
	VPTESTN	%YMM3, %YMM3, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x2)

	movq	%rdi, %r8
	subq	$-(VEC_SIZE * 3), %rdi
	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4
L(first_aligned_loop):
	/* Preserver YMM1, YMM2, and YMM3 until we can gurantee they
	   don't store a match.  */
	VMOVA	(VEC_SIZE * 0)(%rdi), %YMM5
	VMOVA	(VEC_SIZE * 1)(%rdi), %YMM6

	VPCMP	$0, %YMM5, %YMMMATCH, %k2
	vpxord	%YMM6, %YMMMATCH, %YMM7

	VPMIN	%YMM5, %YMM6, %YMM8
	VPMIN	%YMM8, %YMM7, %YMM7

	VPTESTN	%YMM7, %YMM7, %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestd %k1, %k2
	jz	L(first_aligned_loop)

	VPCMP	$0, %YMM6, %YMMMATCH, %k3
	VPTESTN	%YMM8, %YMM8, %k1
	ktestd	%k1, %k1
	jz	L(second_aligned_loop_prep)

	kortestd %k2, %k3
	jnz	L(return_first_aligned_loop)


	/* CHAR is in first VECS.  */
L(first_vec_x1_or_x2):
	VPCMP	$0, %YMM2, %YMMMATCH, %k2
	VPCMP	$0, %YMM3, %YMMMATCH, %k3
	kortestd %k2, %k3
	jz	L(first_vec_x0_test)

	kunpckdq %k2, %k3, %k3
	kmovq	%k3, %rax
	bsrq	%rax, %rax
	leaq	(VEC_SIZE)(%r8, %rax), %rax
	ret

	.p2align 4,, 8
L(return_first_aligned_loop):
	VPTESTN	%YMM5, %YMM5, %k0
	kunpckdq %k0, %k1, %k0
	kmovq	%k0, %rcx

	blsmskq	%rcx, %rcx
	kunpckdq %k2, %k3, %k3
	kmovq	%k3, %rax
	andq	%rcx, %rax
	jz	L(first_vec_x1_or_x2)

	bsrq	%rax, %rax
	leaq	(VEC_SIZE * -2)(%rdi, %rax), %rax
	ret

	.p2align 4
	/* We can throw away the work done for the first 4x checks here
	   as we have a later match. This is the 'fast' path persay.
	 */
L(second_aligned_loop_prep):
L(second_aligned_loop_set_furthest_match):
	movq	%rdi, %rsi
	kunpckdq %k2, %k3, %k4

	.p2align 4
L(second_aligned_loop):
	VMOVU	(VEC_SIZE * 0)(%rdi), %YMM1
	VMOVU	(VEC_SIZE * 1)(%rdi), %YMM2

	VPCMP	$0, %YMM1, %YMMMATCH, %k2
	vpxord	%YMM2, %YMMMATCH, %YMM3

	VPMIN	%YMM1, %YMM2, %YMM4
	VPMIN	%YMM3, %YMM4, %YMM3

	VPTESTN	%YMM3, %YMM3, %k1
	subq	$(VEC_SIZE * -2), %rdi
	kortestd %k1, %k2
	jz	L(second_aligned_loop)

	VPCMP	$0, %YMM2, %YMMMATCH, %k3
	VPTESTN	%YMM4, %YMM4, %k1
	ktestd	%k1, %k1
	jz	L(second_aligned_loop_set_furthest_match)

	kortestd %k2, %k3
	/* branch here because there is a significant advantage interms
	   of output dependency chance in using edx.  */
	jnz	L(return_new_match)
L(return_old_match):
	kmovq	%k4, %rax
	bsrq	%rax, %rax
	leaq	(VEC_SIZE * -2)(%rsi, %rax), %rax
	ret

L(return_new_match):
	VPTESTN	%YMM1, %YMM1, %k0
	kunpckdq %k0, %k1, %k0
	kmovq	%k0, %rcx

	blsmskq	%rcx, %rcx
	kunpckdq %k2, %k3, %k3
	kmovq	%k3, %rax
	andq	%rcx, %rax
	jz	L(return_old_match)

	bsrq	%rax, %rax
	leaq	(VEC_SIZE * -2)(%rdi, %rax), %rax
	ret

	/* This block is horribly aligned (% 16 == 15). This is
	   intentional. The L(cross_page_boundary) block is exactly
	   32-bytes of code size. Ultimately this is a cold case so
	   save the code size by leaving misaligned.  */
L(cross_page_boundary):
	xorq	%rdi, %rax
	VMOVU	(PAGE_SIZE - VEC_SIZE)(%rax), %YMM1
	VPTESTN	%YMM1, %YMM1, %k0
	kmovd	%k0, %ecx
	shrxl	%edi, %ecx, %ecx
	testl	%ecx, %ecx
	jz	L(page_cross_continue)
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kmovd	%k1, %eax
	shrxl	%edi, %eax, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(ret3)
	bsrl	%eax, %eax
	addq	%rdi, %rax
L(ret3):
	ret

END(STRRCHR)
#endif
