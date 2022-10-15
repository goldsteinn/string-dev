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
	lzcnt	%VGPR(rcx), %VGPR(rsi)
	cmpq	%rsi, %rdx
	jbe	L(zero_0)
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(more_1x_vec)
	subq	%rsi, %rax
	ret
	/* Fits in aligning bytes of first cache line.  */

# if VEC_SIZE == 32
	.p2align 4,, 2
L(zero_0):
	xorl	%eax, %eax
	ret
# endif


	.p2align 4,, 10
L(more_1x_vec):
	/* Align rax (pointer to string).  */
	andq	$-VEC_SIZE, %rax
L(page_cross_continue):
	/* Recompute length after aligning.  */
	subq	%rdi, %rax

	cmpq	$(VEC_SIZE * 2), %rax
	ja	L(more_2x_vec)

L(last_2x_vec):
	vpcmpeqb -(VEC_SIZE)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	/* Must dec rax because L(ret_vec_x0_test) expects it.  */
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x0_test)
# if VEC_SIZE == 64
	subl	$VEC_SIZE, %eax
# else
	cmpb	$VEC_SIZE, %al
# endif
	jle	L(zero_2)

	/* Don't use rax for pointer here because EVEX has better
	   encoding with offset % VEC_SIZE == 0.  */
# if VEC_SIZE == 64
	vpcmpeqb -(VEC_SIZE * 1)(%rdi, %rax), %VECMATCH, %k0
# else
	vpcmpeqb -(VEC_SIZE * 2)(%rdi, %rax), %VECMATCH, %k0
# endif
	kmovV	%k0, %VGPR(rcx)
	/* NB: 64-bit lzcnt. This will naturally add 32 to position for
	   VEC_SIZE == 32.  */
	lzcntq	%rcx, %rcx
	subl	%ecx, %eax
	ja	L(ret_vec_x1_ret)
# if VEC_SIZE != 32
L(zero_0):
# endif
L(zero_2):
	xorl	%eax, %eax
	ret

# if VEC_SIZE == 32
L(ret_vec_x1_ret):
	leaq	-1(%rdi, %rax), %rax
	ret

# endif

	.p2align 4,, 6
L(ret_vec_x0_test):
	/* This will naturally add 32 to position.  */
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	subl	%ecx, %eax
	jle	L(zero_2)
# if VEC_SIZE != 32
L(ret_vec_x1_ret):
# endif
	leaq	-1(%rdi, %rax), %rax
	ret




	.p2align 4,, 6
L(loop_last_4x_vec):
	subl	$-(VEC_SIZE * 4), %eax
L(last_4x_vec):
	/* Need no matter what.  */
	cmpl	$(VEC_SIZE * 2), %eax
	jle	L(last_2x_vec)
# if VEC_SIZE == 32
	.p2align 4,, 10
# endif
L(more_2x_vec):

	vpcmpeqb -(VEC_SIZE)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x0)

	vpcmpeqb -(VEC_SIZE * 2)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x1)

	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE * 3)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	subq	$(VEC_SIZE * 4 + 0), %rax
	ja	L(more_4x_vec)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2_test)

	addl	$(VEC_SIZE * 1), %eax
	jle	L(zero_1)

	/* Need no matter what.  */
	vpcmpeqb -(VEC_SIZE * 1)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	lzcnt	%VGPR(rcx), %VGPR(rcx)
	subl	%ecx, %eax
	ja	L(first_vec_x3_ret)
L(zero_1):
	xorl	%eax, %eax
	ret
L(first_vec_x3_ret):
	leaq	-1(%rdi, %rax), %rax
	ret

	.p2align 4,, 6
L(ret_vec_x2_test):
	subl	$-(VEC_SIZE * 2 - 1), %eax
	/* This will naturally add 32 to position.  */
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	subl	%ecx, %eax
	jl	L(zero_4)
	addq	%rdi, %rax
	ret


	.p2align 4,, 10
L(ret_vec_x0):
	/* This will naturally add 32 to position.  */
# if 0
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	leaq	-1(%rdi, %rax), %rax
	subq	%rcx, %rax
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * -1)(%rdi, %rax), %rax
	addq	%rcx, %rax
# endif
	ret
L(zero_4):
	xorl	%eax, %eax
	ret

	.p2align 4,, 10
L(ret_vec_x1):
# if 0
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	leaq	(-1 - VEC_SIZE)(%rdi, %rax), %rax
	subq	%rcx, %rax
	ret
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * -2)(%rdi, %rax), %rax
	addq	%rcx, %rax
	ret
# endif

	.p2align 4,, 8
L(ret_vec_x3):
# if 0
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 1 - 1)(%rdi, %rax), %rax
	subq	%rcx, %rax
	ret
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	addq	%rdi, %rax
	addq	%rcx, %rax
	ret
# endif

	.p2align 4,, 6
L(ret_vec_x2):
# if 0
	lzcnt	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 2 - 1)(%rdi, %rax), %rax
	subq	%rcx, %rax
	ret
# else
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE)(%rdi, %rax), %rax
	addq	%rcx, %rax
	ret
# endif


	.p2align 4,, 10
L(more_4x_vec):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x2)

	vpcmpeqb -(VEC_SIZE * 0)(%rdi, %rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(ret_vec_x3)

	/* Check if near end before re-aligning (otherwise might do an
	   unnecessary loop iteration).  */
	cmpq	$(VEC_SIZE * 4 - 0), %rax
	jbe	L(last_4x_vec)
	leaq	(VEC_SIZE * 3)(%rdi, %rax), %rax
    
# if VEC_SIZE == 64
	xorb	%al, %al
# else
	andq	$-(VEC_SIZE * 4), %rax
# endif
	/* Get endptr for loop in rdx. NB: Can't just do while rax > rdi
	   because lengths that overflow can be valid and break the
	   comparison.  */
	subq	%rdi, %rax
	.p2align 4
L(loop_4x_vec):
	subq	$(VEC_SIZE * 4), %rax
	jbe	L(loop_last_4x_vec)
	/* Store 1 were not-equals and 0 where equals in k1 (used to
	   mask later on).  */
	vpcmpb	$4, (VEC_SIZE * 3)(%rdi, %rax), %VECMATCH, %k1

	/* VEC(2/3) will have zero-byte where we found a CHAR.  */
	vpxorq	(VEC_SIZE * 2)(%rdi, %rax), %VECMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * 1)(%rdi, %rax), %VECMATCH, %VEC(3)
	vpcmpeqb (VEC_SIZE * 0)(%rdi, %rax), %VECMATCH, %k4

	/* Combine VEC(2/3) with min and maskz with k1 (k1 has zero bit
	   where CHAR is found and VEC(2/3) have zero-byte where CHAR
	   is found.  */
	vpminub	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	vptestnmb %VEC(3), %VEC(3), %k2

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
	addq	%rdi, %rax
	addq	%rcx, %rax
	ret

	.p2align 4,, 10
L(ret_vec_x1_end):
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 2)(%rdi, %rax), %rax
	addq	%rcx, %rax
	ret

	.p2align 4,, 4
L(ret_vec_x0_end):
	neg	%VGPR(rcx)
	bsr	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 3)(%rdi, %rax), %rax
	addq	%rcx, %rax
	ret


	.p2align 4,, 4
L(page_cross):
	movzbl	%al, %ecx
	andq	$-VEC_SIZE, %rax
	vpcmpeqb (%rax), %VECMATCH, %k0
	kmovV	%k0, %VGPR(rsi)

	leal	1(%rcx), %r8d

	notl	%ecx
	shlx	%VGPR(rcx), %VGPR(rsi), %VGPR(rsi)


	cmpq	%r8, %rdx
	ja	L(page_cross_check)
	lzcnt	%VGPR(rsi), %VGPR(rsi)
	subl	%esi, %edx
	ja	L(page_cross_ret)
	xorl	%eax, %eax
	ret

L(page_cross_check):
	test	%VGPR(rsi), %VGPR(rsi)
	jz	L(page_cross_continue)

	lzcnt	%VGPR(rsi), %VGPR(rsi)
	subl	%esi, %edx
L(page_cross_ret):
	leaq	-1(%rdi, %rdx), %rax
	ret




END(MEMRCHR)
#endif
