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

#include "../libc-asm-common.h"
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
	.p2align 4,, 6
L(first_vec_x0_return):
	bsrl	%eax, %eax
	addq	%rdi, %rax
L(ret0):
	ret


	.p2align 4,, 6
L(first_vec_x3):
	VPCMP	$0, %YMMMATCH, %YMM4, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(first_vec_x3_return)
	VPCMP	$0, %YMMMATCH, %YMM3, %k1
	kmovd	%k1, %eax
	testl	%eax, %eax
	jz	L(first_vec_x0_x1_test)
	.p2align 4,, 6
L(first_vec_x0_x1_test):
	VPCMP	$0, %YMMMATCH, %YMM2, %k2
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kortestd %k2, %k1
	jz	L(ret2)
	kunpckdq %k2, %k1, %k1
	kmovq	%k1, %rax
	bsrq	%rax, %rax
	addq	%rdi, %rax
L(ret2):
	ret

    
	.p2align 4,, 8
L(first_vec_x1_return):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE)(%rdi, %rax), %rax
	ret

	.p2align 4,, 6
L(first_vec_x1):
	VPCMP	$0, %YMMMATCH, %YMM2, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(first_vec_x1_return)
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kmovd	%k1, %eax
	testl	%eax, %eax
	jnz	L(first_vec_x0_return)
	ret

	.p2align 4,, 6
L(first_vec_x2):
	VPCMP	$0, %YMMMATCH, %YMM3, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x0_x1_test)
L(first_vec_x2_return):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 2)(%rdi, %rax), %rax
	ret

	.p2align 4,, 8
L(first_vec_x3_return):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 3)(%rdi, %rax), %rax
	ret

    
	.p2align 4
L(aligned_more):
	andq	$-VEC_SIZE, %rdi
	VMOVU	VEC_SIZE(%rdi), %YMM2
	VPTESTN	%YMM2, %YMM2, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(first_vec_x1)

	VMOVU	(VEC_SIZE * 2)(%rdi), %YMM3
	VPTESTN	%YMM3, %YMM3, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(first_vec_x2)

	VMOVU	(VEC_SIZE * 3)(%rdi), %YMM4
	VPTESTN	%YMM4, %YMM4, %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(first_vec_x3)

	movq	%rdi, %rsi
	.p2align 4
L(first_aligned_loop):
	/* Preserver YMM1, YMM2, YMM3, and YMM4 until we can gurantee
	   they don't store a match.  */
	VMOVU	(VEC_SIZE * 4)(%rdi), %YMM6
	vpxord	%YMM6, %YMMMATCH, %YMM7
	VPMIN	%YMM6, %YMM7, %YMM8
	VPTESTN	%YMM8, %YMM8, %k1
	kmovd	%k1, %edx
	addq	$VEC_SIZE, %rdi
	testl	%edx, %edx
	jz	L(first_aligned_loop)

	VPTESTN	%YMM6, %YMM6, %k1
	kmovd	%k1, %ecx
	testl	%ecx, %ecx
	jz	L(second_aligned_loop_prep)
	/* Need to re-compute matches instead of just `xorl %ecx, %edx`
	   as we haven't ruled out search CHAR being zero.  */
	VPCMP	$0, %YMM6, %YMMMATCH, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(return_first_aligned_loop)

	VPCMP	$0, %YMM4, %YMMMATCH, %k4
	VPCMP	$0, %YMM3, %YMMMATCH, %k3
	kortestd %k4, %k3
	jz	L(first_vec_x0_x1_test)

	kunpckdq %k4, %k3, %k3
	kmovq	%k3, %rax
	bsrq	%rax, %rax
	leaq	(VEC_SIZE * 2)(%rdi, %rax), %rax
	ret

L(return_first_aligned_loop):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 3)(%rdi, %rax), %rax
	ret


	.p2align 4
	/* We can throw away the work done for the first 4x checks here
	   as we have a later match. This is the 'fast' path persay.
	 */
L(second_aligned_loop_prep):
	subq	$-(VEC_SIZE * 4), %rdi

L(second_aligned_loop_set_furthest_match):
	movl	%edx, %eax
	movq	%rdi, %rsi
	xorl	%ecx, %eax
	/* eax/rsi are our cache. NB the `xorl` only works because we
	   can gurantee search CHAR is non-zero as we only arrive at
	   L(second_aligned_loop) if we had a match of 'c' before the
	   end of the string.  */
	.p2align 4
L(second_aligned_loop):
	VMOVU	(%rdi), %YMM1
	vpxord	%YMM1, %YMMMATCH, %YMM2
	VPMIN	%YMM1, %YMM2, %YMM3
	VPTESTN	%YMM3, %YMM3, %k6
	kmovd	%k6, %edx
	addq	$VEC_SIZE, %rdi
	testl	%edx, %edx
	jz	L(second_aligned_loop)
	VPTESTN	%YMM1, %YMM1, %k7
	kmovd	%k7, %ecx
	testl	%ecx, %ecx
	jz	L(second_aligned_loop_set_furthest_match)
	subl	%ecx, %edx
	/* branch here because there is a significant advantage interms
	   of output dependency chance in using edx.  */
	jnz	L(return_new_match)
L(return_old_match):
	bsrl	%eax, %eax
	addq	%rdi, %rax
	ret

L(return_new_match):
	blsmskl	%ecx, %ecx
	andl	%ecx, %edx
	jz	L(return_old_match)
	bsrl	%edx, %edx
	leaq	(%rdi, %rdx), %rax
	ret

L(cross_page_boundary):
	ret
END(STRRCHR)
#endif
