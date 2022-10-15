/* memrchr optimized with 256-bit EVEX instructions.
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

	// #include <isa-level.h>
#include "../../libc-asm-common.h"
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex512-vecs.h"
#endif
#include "../../libc-defs/libc-reg-macros.h"
#if ISA_SHOULD_BUILD (4)

	// # include <sysdep.h>

# ifndef MEMRCHR
#  define MEMRCHR	__memrchr_evex
# endif

# define PAGE_SIZE	4096
# define VECMATCH	VEC(0)

	.section SECTION(.text), "ax", @progbits
ENTRY_P2ALIGN(MEMRCHR, 6)
# ifdef __ILP32__
	/* Clear upper bits.  */
	and	%RDX_LP, %RDX_LP
# else
	test	%RDX_LP, %RDX_LP
# endif
	jz	L(zero_0)

	/* Get end pointer. Minus one for two reasons. 1) It is
	   necessary for a correct page cross check and 2) it correctly
	   sets up end ptr to be subtract by lzcnt aligned.  */
	leaq	-1(%rdi, %rdx), %rax
	vpbroadcastb %esi, %VECMATCH

	/* Check if we can load 1x VEC without cross a page.  */
	testl	$(PAGE_SIZE - VEC_SIZE), %eax
	jz	L(page_cross)

	/* Don't use rax for pointer here because EVEX has better
	   encoding with offset % VEC_SIZE == 0.  */
	vpcmpeqb -(VEC_SIZE)(%rdi, %rdx), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	/* Fall through for rdx (len) <= VEC_SIZE (expect small sizes).
	 */

	cmpq	$VEC_SIZE, %rdx
	ja	L(more_1x_vec)
L(ret_vec_x0_test):

	/* If ecx is zero (no matches) lzcnt will set it 32 (VEC_SIZE)
	   which will guarantee edx (len) is less than it.  */
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	cmpl	%ecx, %edx
	jle	L(zero_0)
	subq	%rcx, %rax
	ret
	/* Fits in aligning bytes of first cache line.  */
	.p2align 4,, 2
# if VEC_SIZE == 64
L(zero_3):
# endif
L(zero_0):
	xorl	%eax, %eax
	ret

	.p2align 4,, 9
L(ret_vec_x0_dec):
	decq	%rax
L(ret_vec_x0):
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	subq	%rcx, %rax
	ret

# if VEC_SIZE == 32
L(zero_3):
	xorl	%eax, %eax
	ret
# endif
	.p2align 4,, 10
L(more_1x_vec):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x0)

	/* Align rax (pointer to string).  */
	andq	$-VEC_SIZE, %rax
	/* Recompute length after aligning.  */
	movq	%rax, %rdx
	subq	%rdi, %rdx

	cmpq	$(VEC_SIZE * 2), %rdx
	ja	L(more_2x_vec)
L(last_2x_vec):
	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	/* Must dec rax because L(ret_vec_x0_test) expects it.  */
	decq	%rax
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x0_test)

	cmpl	$VEC_SIZE, %edx
	jbe	L(zero_3)

	/* Don't use rax for pointer here because EVEX has better
	   encoding with offset % VEC_SIZE == 0.  */
	vpcmpeqb -(VEC_SIZE * 2)(%rdi, %rdx), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	/* NB: 64-bit lzcnt. This will naturally add 32 to position for
	   VEC_SIZE == 32.  */
# if VEC_SIZE == 64
	shrx	%VGPR(rdi), %VGPR(rcx), %VGPR(rdx)
	test	%VGPR(rdx), %VGPR(rdx)
	jnz	L(ret_vec_x1_inc)
# else
	lzcntq	%rcx, %rcx
	cmpl	%ecx, %edx
	jle	L(zero_2)
	subq	%rcx, %rax
	ret
# endif
L(zero_2):
	xorl	%eax, %eax
	ret

	.p2align 4,, 10
# if VEC_SIZE == 64
L(ret_vec_x1_inc):
	incq	%rax
# endif
L(ret_vec_x1):
	/* This will naturally add 32 to position.  */
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 2)(%rcx, %rax), %rax
	ret

# if VEC_SIZE == 32
	.p2align 4,, 7
# endif
L(loop_last_4x_vec):
	subl	$-(VEC_SIZE * 4), %edx
L(last_4x_vec):
	addq	$-(VEC_SIZE * 4), %rax
	/* Need no matter what.  */
	cmpl	$(VEC_SIZE * 2), %edx
	jle	L(last_2x_vec)
	.p2align 4,, 4
L(more_2x_vec):
	vpcmpeqb -(VEC_SIZE)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x0_dec)

	vpcmpeqb -(VEC_SIZE * 2)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x1)

	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE * 3)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	subq	$(VEC_SIZE * 4), %rdx
	ja	L(more_4x_vec)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2_test)

	cmpl	$(VEC_SIZE * -1), %edx
	jle	L(zero_1)


	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE * 4)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
    # if VEC_SIZE == 64

	shrx	%VGPR(rdi), %VGPR(rcx), %VGPR(rdx)
	test	%VGPR(rdx), %VGPR(rdx)
	jz	L(zero_1)
L(ret_vec_x3):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 4)(%rcx, %rax), %rax
	ret
# else
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(zero_1)
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 4)(%rcx, %rax), %rax
	cmpq	%rax, %rdi
	ja	L(zero_1)
	ret

L(zero_1):
	xorl	%eax, %eax
	ret
# endif

	.p2align 4,, 4
L(ret_vec_x2_test):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 3)(%rcx, %rax), %rax
	cmpq	%rax, %rdi
# if VEC_SIZE == 32
	ja	L(zero_1)
	ret
# else
	jbe	L(ret_1)
L(zero_1):
	xorl	%eax, %eax
L(ret_1):
	ret
# endif

# if VEC_SIZE == 32
	.p2align 4,, 8
L(ret_vec_x3):

	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 4)(%rcx, %rax), %rax
	ret
	.p2align 4,, 8

L(ret_vec_x2):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 3)(%rcx, %rax), %rax
	ret
# endif
	.p2align 4,, 10
L(more_4x_vec):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2)

	vpcmpeqb -(VEC_SIZE * 4)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x3)

	/* Check if near end before re-aligning (otherwise might do an
	   unnecessary loop iteration).  */
	cmpq	$(VEC_SIZE * 4), %rdx
	jbe	L(last_4x_vec)

	addq	$(VEC_SIZE * 3), %rax
# if VEC_SIZE == 64
	xorb	%al, %al
# else
	andq	$-(VEC_SIZE * 4), %rax
# endif
	/* Get endptr for loop in rdx. NB: Can't just do while rax > rdi
	   because lengths that overflow can be valid and break the
	   comparison.  */
	leaq	-(VEC_SIZE * 4)(%rax), %rdx
	subq	%rdi, %rdx
	.p2align 4
L(loop_4x_vec):
	subq	$(VEC_SIZE * 4), %rdx
	jbe	L(loop_last_4x_vec)

	/* Store 1 were not-equals and 0 where equals in k1 (used to
	   mask later on).  */
	vpcmpb	$4, (VEC_SIZE * -5)(%rax), %VECMATCH, %k1

	/* VEC(2/3) will have zero-byte where we found a CHAR.  */
	vpxorq	(VEC_SIZE * -6)(%rax), %VECMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * -7)(%rax), %VECMATCH, %VEC(3)
	vpcmpeqb (VEC_SIZE * -8)(%rax), %VECMATCH, %k4

	/* Combine VEC(2/3) with min and maskz with k1 (k1 has zero bit
	   where CHAR is found and VEC(2/3) have zero-byte where CHAR
	   is found.  */
	vpminub	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	vptestnmb %VEC(3), %VEC(3), %k2

	addq	$-(VEC_SIZE * 4), %rax
	/* Any 1s and we found CHAR.  */
	kortestV %k2, %k4
	jz	L(loop_4x_vec)

	kmovV	%k1, %VGPR(rcx)
	inc	%VGPR(rcx)
	jnz	L(ret_vec_x0_end)

	vptestnmb %VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x1_end)
	kmovV	%k2, %VGPR(rcx)

	/* Combine last 2 VEC matches. If ecx (VEC3) is zero (no CHAR in
	   VEC3) then it won't affect the result in esi (VEC4). If ecx
	   is non-zero then CHAR in VEC3 and bsrq will use that
	   position.  */
# if VEC_SIZE == 64
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2)
	kmovV	%k4, %VGPR(rcx)
# else
	kmovV	%k4, %VGPR(rsi)
	salq	$32, %rcx
	orq	%rsi, %rcx
# endif
	bsrq	%rcx, %rcx
	leaq	(VEC_SIZE * -4)(%rax, %rcx), %rax
	ret

	.p2align 4,, 4
L(ret_vec_x0_end):
	neg	%VGPR(rcx)
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * -1)(%rax, %rcx), %rax
	ret

	.p2align 4,, 6
L(ret_vec_x1_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	nop
	leaq	(VEC_SIZE * -2)(%rax, %rcx), %rax
	ret

# if VEC_SIZE == 64
	.p2align 4,, 8
L(ret_vec_x2):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * -3)(%rax, %rcx), %rax
	ret
# endif


	.p2align 4,, 4
L(page_cross):
	movq	%rax, %rsi
	andq	$-VEC_SIZE, %rsi
	vpcmpeqb (%rsi), %VECMATCH, %k0
	kmovV	%k0, %VGPR(r8)
	movl	%eax, %ecx
	notl	%ecx
	shlx	%VGPR(rcx), %VGPR(r8), %VGPR(rcx)
	cmpq	%rdi, %rsi
	ja	L(more_1x_vec)
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	cmpl	%ecx, %edx
	jle	L(zero_page_cross)
	subq	%rcx, %rax
	ret

L(zero_page_cross):
	xorl	%eax, %eax
	ret

END(MEMRCHR)
#endif
