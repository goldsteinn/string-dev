/* __memcmpeq optimized with EVEX.
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

	/* __memcmpeq is implemented as: 1. Use ymm vector compares when
	   possible. The only case where vector compares is not
	   possible for when size < VEC_SIZE and loading from either s1
	   or s2 would cause a page cross. 2. Use xmm vector compare
	   when size >= 8 bytes. 3. Optimistically compare up to first
	   4 * VEC_SIZE one at a to check for early mismatches. Only do
	   this if its guranteed the work is not wasted. 4. If size is
	   8 * VEC_SIZE or less, unroll the loop. 5. Compare 4 *
	   VEC_SIZE at a time with the aligned first memory area. 6.
	   Use 2 vector compares when size is 2 * VEC_SIZE or less. 7.
	   Use 4 vector compares when size is 4 * VEC_SIZE or less. 8.
	   Use 8 vector compares when size is 8 * VEC_SIZE or less.  */

	// # include <sysdep.h>

# ifndef MEMCMPEQ
#  define MEMCMPEQ	__memcmpeq_evex
# endif

# ifndef VEC_SIZE
#  include "../../libc-defs/libc-evex256-vecs.h"
# endif
# include "../../libc-defs/libc-reg-macros.h"
# if VEC_SIZE == 32
#  define S1_ACCESS_END	%rsi, %rdx
#  define CMP_END	cmpl
#  define CMP_END_OFFSET	0

#  define TEST_ZERO(reg)	test %VGPR(reg), %VGPR(reg)
#  define TO_32BIT_P1(reg)	/* Do nothing. */
#  define TO_32BIT_P2(reg)	/* Do nothing. */
#  define TO_32BIT(reg)	/* Do nothing. */
# elif VEC_SIZE == 64
#  define S1_ACCESS_END	%rsi
	// #  define CMP_END       subl
	// #  define CMP_END_OFFSET        (VEC_SIZE * -3)

#  define CMP_END	cmpl
#  define CMP_END_OFFSET	0

#  define TEST_ZERO(reg)	neg %VGPR(reg)
#  define TO_32BIT_P1(reg)	TEST_ZERO(reg)
#  define TO_32BIT_P2(reg)	sbb %VGPR_SZ(reg, 32), %VGPR_SZ(reg, 32)
#  define TO_32BIT(reg)	popcntq %reg, %reg
# else
#  error "Unsupported VEC_SIZE"
# endif


# define VMOVU_MASK	vmovdqu8
# define VPCMP	vpcmpub
# define VPTEST	vptestmb

# define PAGE_SIZE	4096


	.section .text.evex, "ax", @progbits
ENTRY_P2ALIGN(MEMCMPEQ, 6)
# ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%edx, %edx
# endif
	cmp	$VEC_SIZE, %RDX_LP
	/* Fall through for [0, VEC_SIZE] as its the hottest.  */
	ja	L(more_1x_vec)

	/* Create mask of bytes that are guranteed to be valid because
	   of length (edx). Using masked movs allows us to skip checks
	   for page crosses/zero size.  */
	mov	$-1, %VRAX
	bzhi	%VRDX, %VRAX, %VRAX
	KMOV	%VRAX, %k2

	/* Use masked loads as VEC_SIZE could page cross where length
	   (edx) would not.  */
	VMOVU_MASK (%rsi), %VMM(2){%k2}{z}
	VPCMP	$4, (%rdi), %VMM(2), %k1{%k2}
	KMOV	%k1, %VRAX

	TO_32BIT (VRAX)
	ret
# define OFFSET	0
	.p2align 4,, 3
L(last_1x_vec):
	VMOVU	-(VEC_SIZE * 1-(OFFSET))(%rsi, %rdx), %VMM(1)
	VPCMP	$4, -(VEC_SIZE * 1-(OFFSET))(%rdi, %rdx), %VMM(1), %k1
	KMOV	%k1, %VRAX
	TO_32BIT_P1 (rax)
L(return_neq0):
	TO_32BIT_P2 (rax)
	ret



	.p2align 4,, 12
L(more_1x_vec):
	/* From VEC + 1 to 2 * VEC.  */
	VMOVU	(%rsi), %VMM(1)
	/* Use compare not equals to directly check for mismatch.  */
	VPCMP	$4, (%rdi), %VMM(1), %k1
	KMOV	%k1, %VRAX
	TEST_ZERO (rax)
	jnz	L(return_neq0)

	cmpq	$(VEC_SIZE * 2), %rdx
	jbe	L(last_1x_vec)

	/* Check second VEC no matter what.  */
	VMOVU	VEC_SIZE(%rsi), %VMM(2)
	VPCMP	$4, VEC_SIZE(%rdi), %VMM(2), %k1
	KMOV	%k1, %VRAX
	TEST_ZERO (rax)
	jnz	L(return_neq0)

	/* Less than 4 * VEC.  */
	cmpq	$(VEC_SIZE * 4 -(OFFSET)), %rdx
	jbe	L(last_2x_vec)

	/* Check third and fourth VEC no matter what.  */
	VMOVU	(VEC_SIZE * 2)(%rsi), %VMM(3)
	VPCMP	$4, (VEC_SIZE * 2)(%rdi), %VMM(3), %k1
	KMOV	%k1, %VRAX
	TEST_ZERO (rax)
	jnz	L(return_neq0)

	VMOVU	(VEC_SIZE * 3)(%rsi), %VMM(4)
	VPCMP	$4, (VEC_SIZE * 3)(%rdi), %VMM(4), %k1
	KMOV	%k1, %VRAX
	TEST_ZERO (rax)
	jnz	L(return_neq0)

	/* Go to 4x VEC loop.  */
	cmpq	$(VEC_SIZE * 8 -(OFFSET)), %rdx
	ja	L(more_8x_vec)

	/* Handle remainder of size = 4 * VEC + 1 to 8 * VEC without any
	   branches.  */

	VMOVU	-(VEC_SIZE * 1 -(OFFSET))(%rsi, %rdx), %VMM(1)
	VMOVU	-(VEC_SIZE * 2 -(OFFSET))(%rsi, %rdx), %VMM(2)
	addq	%rdx, %rdi

	/* Wait to load from s1 until addressed adjust due to
	   unlamination.  */

	/* vpxor will be all 0s if s1 and s2 are equal. Otherwise it
	   will have some 1s.  */
	vpxorq	-(VEC_SIZE * 1 -(OFFSET))(%rdi), %VMM(1), %VMM(1)
	/* Ternary logic to xor -(VEC_SIZE * 3)(%rdi) with VEC(2) while
	   oring with VEC(1). Result is stored in VEC(1).  */
	vpternlogd $0xde, -(VEC_SIZE * 2 -(OFFSET))(%rdi), %VMM(1), %VMM(2)
# if VEC_SIZE == 64
	cmpl	$(VEC_SIZE * 6 -(OFFSET)), %edx
	jbe	L(4x_last_2x_vec)
# else
	cmpb	$(VEC_SIZE * 6 -(OFFSET)), %dl
	jbe	L(4x_last_2x_vec)
# endif
	VMOVU	-(VEC_SIZE * 3 -(OFFSET))(%rsi, %rdx), %VMM(3)
	vpxorq	-(VEC_SIZE * 3 -(OFFSET))(%rdi), %VMM(3), %VMM(3)
	/* Or together VEC(1), VEC(2), and VEC(3) into VEC(3).  */
	VMOVU	-(VEC_SIZE * 4 -(OFFSET))(%rsi, %rdx), %VMM(4)
	vpxorq	-(VEC_SIZE * 4 -(OFFSET))(%rdi), %VMM(4), %VMM(4)

	/* Or together VEC(4), VEC(3), and VEC(2) into VEC(2).  */
	vpternlogd $0xfe, %VMM(4), %VMM(3), %VMM(2)

	/* Compare VEC(4) with 0. If any 1s s1 and s2 don't match.  */
L(4x_last_2x_vec):
	VPTEST	%VMM(2), %VMM(2), %k1
	KMOV	%k1, %VRAX
	TO_32BIT (VRAX)
	ret

	.p2align 4,, 10
L(more_8x_vec):
	/* Set end of s1 in rdx.  */
	leaq	-(VEC_SIZE * 4 -(OFFSET))(%rdi, %rdx), %rdx
	/* rsi stores s2 - s1. This allows loop to only update one
	   pointer.  */
	subq	%rdi, %rsi
	/* Align s1 pointer.  */
	andq	$-VEC_SIZE, %rdi
	/* Adjust because first 4x vec where check already.  */
	subq	$-(VEC_SIZE * 4), %rdi
	.p2align 4
L(loop_4x_vec):
	VMOVU	(%rsi, %rdi), %VMM(1)
	vpxorq	(%rdi), %VMM(1), %VMM(1)

	VMOVU	VEC_SIZE(%rsi, %rdi), %VMM(2)
	vpternlogd $0xde, (VEC_SIZE)(%rdi), %VMM(1), %VMM(2)

	VMOVU	(VEC_SIZE * 2)(%rsi, %rdi), %VMM(3)
	vpxorq	(VEC_SIZE * 2)(%rdi), %VMM(3), %VMM(3)

	VMOVU	(VEC_SIZE * 3)(%rsi, %rdi), %VMM(4)
	vpxorq	(VEC_SIZE * 3)(%rdi), %VMM(4), %VMM(4)

	vpternlogd $0xfe, %VMM(2), %VMM(3), %VMM(4)
	VPTEST	%VMM(4), %VMM(4), %k1
	KMOV	%k1, %VRAX
	TEST_ZERO (rax)
	jnz	L(return_neq2)
	subq	$-(VEC_SIZE * 4), %rdi
	cmpq	%rdx, %rdi
	jb	L(loop_4x_vec)

	subq	%rdx, %rdi
# if VEC_SIZE == 64
	addq	%rdx, %rsi
# endif


	VMOVU	(VEC_SIZE * 3)(S1_ACCESS_END), %VMM(4)
	vpxorq	(VEC_SIZE * 3)(%rdx), %VMM(4), %VMM(4)
	/* rdi has 4 * VEC_SIZE - remaining length.  */
	cmpl	$(VEC_SIZE * 3), %edi
	jge	L(8x_last_1x_vec)
	/* Load regardless of branch.  */
	VMOVU	(VEC_SIZE * 2)(S1_ACCESS_END), %VMM(3)
	/* Ternary logic to xor (VEC_SIZE * 2)(%rdx) with VEC(3) while
	   oring with VEC(4). Result is stored in VEC(4).  */
	vpternlogd $0xf6, (VEC_SIZE * 2)(%rdx), %VMM(3), %VMM(4)
# if VEC_SIZE == 64
	testb	%dil, %dil
	js	L(8x_last_2x_vec)
# else
	cmpl	$(VEC_SIZE * 2), %edi
	jge	L(8x_last_2x_vec)
# endif

	VMOVU	VEC_SIZE(S1_ACCESS_END), %VMM(2)
	vpxorq	VEC_SIZE(%rdx), %VMM(2), %VMM(2)

	VMOVU	(S1_ACCESS_END), %VMM(1)
	vpxorq	(%rdx), %VMM(1), %VMM(1)

	vpternlogd $0xfe, %VMM(1), %VMM(2), %VMM(4)
L(8x_last_1x_vec):
L(8x_last_2x_vec):
	VPTEST	%VMM(4), %VMM(4), %k1
	KMOV	%k1, %VRAX
	TO_32BIT_P1 (rax)
L(return_neq2):
	TO_32BIT_P2 (rax)
	ret

	.p2align 4,, 8
L(last_2x_vec):
	VMOVU	-(VEC_SIZE * 2 -(OFFSET))(%rsi, %rdx), %VMM(1)
	vpxorq	-(VEC_SIZE * 2 -(OFFSET))(%rdi, %rdx), %VMM(1), %VMM(1)
	VMOVU	-(VEC_SIZE * 1 -(OFFSET))(%rsi, %rdx), %VMM(2)
	vpternlogd $0xde, -(VEC_SIZE * 1 -(OFFSET))(%rdi, %rdx), %VMM(1), %VMM(2)
	VPTEST	%VMM(2), %VMM(2), %k1
	KMOV	%k1, %VRAX
	TO_32BIT (VRAX)
	ret

	/* evex256: 1 Bytes from next cache line. evex512: 15 Bytes from
	   next cache line.  */
END(MEMCMPEQ)
#endif
