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
#  define SHIFT_REG	esi
#  define kunpck	kunpckbw
#  define CHAR_SIZE	4
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
# else
#  define SHIFT_REG	edi
#  define kunpck	kunpckdq
#  define CHAR_SIZE	1
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
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
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
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
# ifdef USE_AS_WCSRCHR
	leaq	(%rsi, %rax, CHAR_SIZE), %rax
# else
	addq	%rsi, %rax
# endif
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
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(first_vec_x2):
	VPCMP	$0, %YMMMATCH, %YMM3, %k1
	kmovd	%k1, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x0_x1_test)
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
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
	.p2align 4
L(first_aligned_loop):
	/* Preserver YMM1, YMM2, and YMM3 until we can gurantee they
	   don't store a match.  */
	VMOVU	(VEC_SIZE * 3)(%rdi), %YMM4
	VPCMP	$0, %YMM4, %YMMMATCH, %k2
	VPTESTN	%YMM4, %YMM4, %k1

	addq	$VEC_SIZE, %rdi
	kortestd %k1, %k2
	jz	L(first_aligned_loop)

	kmovd	%k1, %ecx
	testl	%ecx, %ecx
	jz	L(second_aligned_loop_prep)

	/* Need to re-compute matches instead of just `xorl %ecx, %edx`
	   as we haven't ruled out search CHAR being zero.  */
	kmovd	%k2, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jnz	L(return_first_aligned_loop)

	VPCMP	$0, %YMM3, %YMMMATCH, %k3
	VPCMP	$0, %YMM2, %YMMMATCH, %k2
	kortestd %k2, %k3
	jz	L(first_vec_x0_test)

	kunpck	%k2, %k3, %k3
# ifdef USE_AS_WCSRCHR
	kmovd	%k3, %eax
	bsrl	%eax, %eax
# else
	kmovq	%k3, %rax
	bsrq	%rax, %rax
# endif

	leaq	(VEC_SIZE)(%r8, %rax, CHAR_SIZE), %rax
	ret

L(return_first_aligned_loop):

	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4
	/* We can throw away the work done for the first 4x checks here
	   as we have a later match. This is the 'fast' path persay.
	 */
L(second_aligned_loop_prep):
L(second_aligned_loop_set_furthest_match):
	movq	%rdi, %rsi
	kmovd	%k2, %eax
	/* eax/rsi are our cache. NB the `xorl` only works because we
	   can gurantee search CHAR is non-zero as we only arrive at
	   L(second_aligned_loop) if we had a match of 'c' before the
	   end of the string.  */
	.p2align 4
L(second_aligned_loop):
	VMOVU	(VEC_SIZE * 3)(%rdi), %YMM1
	VPCMP	$0, %YMM1, %YMMMATCH, %k2
	VPTESTN	%YMM1, %YMM1, %k1
	addq	$VEC_SIZE, %rdi
	kortestd %k2, %k1
	jz	L(second_aligned_loop)
	ktestd	%k1, %k1
	jz	L(second_aligned_loop_set_furthest_match)

	ktestd	%k2, %k2
	/* branch here because there is a significant advantage interms
	   of output dependency chance in using edx.  */
	jnz	L(return_new_match)
L(return_old_match):
	bsrl	%eax, %eax
	leaq	(VEC_SIZE * 2)(%rsi, %rax, CHAR_SIZE), %rax
	ret

L(return_new_match):
	kmovd	%k1, %ecx
	kmovd	%k2, %edx
	/* Guranteed search char is non-zero so safe to use decl instead
	   of blsmsk.  */
	decl	%ecx
	andl	%ecx, %edx
	jz	L(return_old_match)

	bsrl	%edx, %edx
	leaq	(VEC_SIZE * 2)(%rdi, %rdx, CHAR_SIZE), %rax
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
# ifdef USE_AS_WCSRCHR
	movl	%edi, %esi
    andl    $(VEC_SIZE - 1), %esi
	shrl	$2, %esi

# endif
	shrxl	%SHIFT_REG, %ecx, %ecx
	testl	%ecx, %ecx
	jz	L(page_cross_continue)
	VPCMP	$0, %YMMMATCH, %YMM1, %k1
	kmovd	%k1, %eax
	shrxl	%SHIFT_REG, %eax, %eax
	blsmskl	%ecx, %ecx
	andl	%ecx, %eax
	jz	L(ret3)
	bsrl	%eax, %eax
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
L(ret3):
	ret

END(STRRCHR)
#endif
