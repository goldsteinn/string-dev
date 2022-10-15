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
# include "../../libc-defs/libc-evex-vecs.h"
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
L(last_4x_vec):
	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	cmpq	$(VEC_SIZE * 2), %rdx
	ja	L(more_2x_vec)

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
	bsr	%VGPR(rcx), %VGPR(rcx)
	jz	L(zero_2)
	leaq	-(VEC_SIZE * 2)(%rcx, %rax), %rax
	cmpq	%rax, %rdi
	ja	L(zero_2)
# else
	lzcntq	%rcx, %rcx
	cmpl	%ecx, %edx
	jle	L(zero_2)
	subq	%rcx, %rax
# endif
	ret

	.p2align 4,, 8
L(ret_vec_x1):
	/* This will naturally add 32 to position.  */
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 2)(%rcx, %rax), %rax
	ret

L(zero_2):
	xorl	%eax, %eax
	ret

	.p2align 4,, 4
L(more_2x_vec):
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
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(zero_1)
L(ret_vec_x3_test):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 4)(%rcx, %rax), %rax
	cmpq	%rax, %rdi
	ja	L(zero_1)
	ret
L(zero_1):
	xorl	%eax, %eax
	ret


	.p2align 4,, 8
L(ret_vec_x2_test):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 3)(%rcx, %rax), %rax
	cmpq	%rax, %rdi
	ja	L(zero_1)
	ret

	.p2align 4,, 8
L(ret_vec_x3):
# if VEC_SIZE == 32
	subq	$VEC_SIZE, %rax
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 4)(%rcx, %rax), %rax
	ret
# endif
L(ret_vec_x2):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	-(VEC_SIZE * 3)(%rcx, %rax), %rax
	ret

	.p2align 4,, 2
	.p2align 5,, 8
L(more_4x_vec):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2)

	vpcmpeqb -(VEC_SIZE * 4)(%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x3)

	/* Check if near end before re-aligning (otherwise might do an
	   unnecessary loop iteration).  */
	addq	$-(VEC_SIZE * 4), %rax
	cmpq	$(VEC_SIZE * 4), %rdx
	jbe	L(last_4x_vec)

	decq	%rax
	andq	$-(VEC_SIZE * 4), %rax
	movq	%rdi, %rdx
	/* Get endptr for loop in rdx. NB: Can't just do while rax > rdi
	   because lengths that overflow can be valid and break the
	   comparison.  */
	andq	$-(VEC_SIZE * 4), %rdx

	.p2align 4
L(loop_4x_vec):
	/* Store 1 were not-equals and 0 where equals in k1 (used to
	   mask later on).  */
	vpcmpb	$4, (VEC_SIZE * 3)(%rax), %VECMATCH, %k1

	/* VEC(2/3) will have zero-byte where we found a CHAR.  */
	vpxorq	(VEC_SIZE * 2)(%rax), %VECMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * 1)(%rax), %VECMATCH, %VEC(3)
	vpcmpeqb (VEC_SIZE * 0)(%rax), %VECMATCH, %k4

	/* Combine VEC(2/3) with min and maskz with k1 (k1 has zero bit
	   where CHAR is found and VEC(2/3) have zero-byte where CHAR
	   is found.  */
	vpminub	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	vptestnmb %VEC(3), %VEC(3), %k2

	cmpq	%rdx, %rax
	je	L(loop_last_4x_vec)

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
	jnz	L(ret_vec_x2_end)
	kmovV	%k4, %VGPR(rcx)
# else
	kmovV	%k4, %VGPR(rsi)
	salq	$32, %rcx
	orq	%rsi, %rcx
# endif
	bsrq	%rcx, %rcx
	leaq	(VEC_SIZE * 4)(%rax, %rcx), %rax
	ret

	.p2align 4,, 4
L(ret_vec_x0_end):
	neg	%VGPR(rcx)
# if VEC_SIZE == 32
	addq	$(VEC_SIZE), %rax
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 7)(%rax, %rcx), %rax
	ret
# endif
L(ret_vec_x1_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 6)(%rax, %rcx), %rax
	ret

# if VEC_SIZE == 64
	.p2align 4,, 8
L(ret_vec_x2_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 5)(%rax, %rcx), %rax
	ret
# endif

	.p2align 4
L(loop_last_4x_vec):
	kortestV %k2, %k4
	jz	L(zero_end_1)
	/* Need to re-adjust rdx / rax for L(last_4x_vec).  */
	subl	%edi, %edx

	kmovV	%k1, %VGPR(rcx)
	cmpl	$(VEC_SIZE * -2), %edx
	jg	L(loop_last_4x_vec_more_2x)

	subq	$(VEC_SIZE * -4 + 1), %rax
	inc	%VGPR(rcx)
	jnz	L(loop_last_4x_vec_check_x1)

	cmpl	$(VEC_SIZE * -3), %edx
	jle	L(zero_end_1)

	vptestnmb %VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(loop_last_4x_vec_check)
L(zero_end_1):
	xorl	%eax, %eax
	ret


L(loop_last_4x_vec_check_x1):
	neg	%VGPR(rcx)
L(loop_last_4x_vec_check_x3):
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	subq	%rcx, %rax
	cmpq	%rax, %rdi
	ja	L(zero_end_1)
	ret

# if VEC_SIZE == 64
	.p2align 4,, 4
L(loop_vec_x0_end):
	neg	%VGPR(rcx)
	addq	$(VEC_SIZE), %rax
L(loop_vec_x1_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 2)(%rax, %rcx), %rax
	ret
# endif
	.p2align 4,, 8
L(loop_last_4x_vec_more_2x):
	inc	%VGPR(rcx)
	jnz	L(loop_vec_x0_end)

	vptestnmb %VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(loop_vec_x1_end)

	kmovV	%k2, %VGPR(rcx)
	subq	$(VEC_SIZE * -2 + 1), %rax
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(loop_last_4x_vec_check_x3)

	cmpl	$(VEC_SIZE * -1), %edx
	jle	L(zero_end_1)

	kmovV	%k4, %VGPR(rcx)
L(loop_last_4x_vec_check):
	lzcntq	%rcx, %rcx
# if VEC_SIZE == 64
	addl	$VEC_SIZE, %ecx
# endif
	subq	%rcx, %rax
	cmpq	%rax, %rdi
	ja	L(zero_end_1)
	ret

# if VEC_SIZE == 32
	.p2align 4,, 4
L(loop_vec_x0_end):
	neg	%VGPR(rcx)
	addq	$(VEC_SIZE), %rax
L(loop_vec_x1_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 2)(%rax, %rcx), %rax
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
