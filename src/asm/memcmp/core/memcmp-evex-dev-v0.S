/* memcmp/wmemcmp optimized with 256-bit EVEX instructions.
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
# ifndef VEC_SIZE
#  include "../../libc-defs/libc-evex512-vecs.h"
# endif

	/* memcmp/wmemcmp is implemented as: 1. Use ymm vector compares
	   when possible. The only case where vector compares is not
	   possible for when size < CHAR_PER_VEC and loading from
	   either s1 or s2 would cause a page cross. 2. For size from 2
	   to 7 bytes on page cross, load as big endian with movbe and
	   bswap to avoid branches. 3. Use xmm vector compare when size
	   >= 4 bytes for memcmp or size >= 8 bytes for wmemcmp. 4.
	   Optimistically compare up to first 4 * CHAR_PER_VEC one at a
	   to check for early mismatches. Only do this if its guranteed
	   the work is not wasted. 5. If size is 8 * VEC_SIZE or less,
	   unroll the loop. 6. Compare 4 * VEC_SIZE at a time with the
	   aligned first memory area. 7. Use 2 vector compares when
	   size is 2 * CHAR_PER_VEC or less. 8. Use 4 vector compares
	   when size is 4 * CHAR_PER_VEC or less. 9. Use 8 vector
	   compares when size is 8 * CHAR_PER_VEC or less. When
	   possible the implementation tries to optimize for frontend
	   in the following ways: Throughput: 1. All code sections that
	   fit are able to run optimally out of the LSD. 2. All code
	   sections that fit are able to run optimally out of the DSB
	   3. Basic blocks are contained in minimum number of fetch
	   blocks necessary. Latency: 1. Logically connected basic
	   blocks are put in the same cache-line. 2. Logically
	   connected basic blocks that do not fit in the same cache-
	   line are put in adjacent lines. This can get beneficial L2
	   spatial prefetching and L1 next-line prefetching.  */

	// # include <sysdep.h>

# ifndef MEMCMP
#  define MEMCMP	__memcmp_evex_movbe
# endif


	/* There are a few places we want seperate logic for evex256 and
	   evex512 to get imm8 encoding.  */
# if VEC_SIZE == 32
#  define LAST_VEC_OFFSET	(0)

#  define CMP_END	cmpl
#  define CMP_END_OFFSET	0
# elif VEC_SIZE == 64
#  define LAST_VEC_OFFSET	(96)

#  define CMP_END	subl
#  define CMP_END_OFFSET	(VEC_SIZE * -3)
# else
#  error "Unsupported VEC_SIZE"
# endif


# ifdef USE_AS_WMEMCMP
#  define VMOVU_MASK	vmovdqu32
#  define CHAR_SIZE	4
#  define VPCMP	vpcmpd
#  define VPTEST	vptestmd
#  define VPCMPEQ	vpcmpeqd

#  define USE_WIDE_CHAR
# else
#  define VMOVU_MASK	vmovdqu8
#  define CHAR_SIZE	1
#  define VPCMP	vpcmpub
#  define VPCMPEQ	vpcmpeqb
#  define VPTEST	vptestmb
# endif

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# include "../../libc-defs/libc-reg-macros.h"

	/* Warning! wmemcmp has to use SIGNED comparison for elements.
	   memcmp has to use UNSIGNED comparison for elemnts.  */

	.section .text.evex, "ax", @progbits
	/* Cache align memcmp entry. This allows for much more thorough
	   frontend optimization.  */
ENTRY_P2ALIGN(MEMCMP, 6)
# ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%edx, %edx
# endif
	cmp	$CHAR_PER_VEC, %RDX_LP
	/* Fall through for [0, VEC_SIZE] as its the hottest.  */
	ja	L(more_1x_vec)

	/* Create mask of VEC_SIZE width for CHAR's we want to compare.
	   This allows us to avoid having to include page cross logic.  */
	mov	$-1, %VRCX
	bzhi	%VRDX, %VRCX, %VRCX
	// jz	L(zero)
	KMOV	%VRCX, %k2

	/* Safe to load full ymm with mask.  */
	VMOVU_MASK (%rsi), %VMM(2){%k2}
	VPCMPEQ	(%rdi), %VMM(2), %k1{%k2}
	KMOV	%k1, %VRAX
	sub	%VRCX, %VRAX
	jnz	L(return_vec_0)
L(zero):
	// xorl	%eax, %eax
	ret

	.p2align 4,, 11
L(return_vec_0):
	bsf	%VRAX, %VRAX
# ifdef USE_AS_WMEMCMP
	movl	(%rdi, %rax, CHAR_SIZE), %ecx
	xorl	%edx, %edx
	cmpl	(%rsi, %rax, CHAR_SIZE), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	(%rsi, %rax), %ecx
	movb	(%rdi, %rax), %al
	subl	%ecx, %eax
# endif
	ret

	.p2align 4,, 11
L(more_1x_vec):
	/* From VEC to 2 * VEC.  No branch when size == VEC_SIZE.  */
	VMOVU	(%rsi), %VMM(1)
	/* Use compare not equals to directly check for mismatch.  */
	VPCMP	$4, (%rdi), %VMM(1), %k1
	KMOV	%k1, %VRAX
	/* NB: eax must be destination register if going to
	   L(return_vec_[0,2]). For L(return_vec_3) destination
	   register must be ecx.  */
	test	%VRAX, %VRAX
	jnz	L(return_vec_0)

	cmpq	$(CHAR_PER_VEC * 2), %rdx
	jbe	L(last_1x_vec)

	/* Check second VEC no matter what.  */
	VMOVU	VEC_SIZE(%rsi), %VMM(2)
	VPCMP	$4, VEC_SIZE(%rdi), %VMM(2), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_1)

	/* Less than 4 * VEC.  */
	cmpq	$(CHAR_PER_VEC * 4), %rdx
	jbe	L(last_2x_vec)

	/* Check third and fourth VEC no matter what.  */
	VMOVU	(VEC_SIZE * 2)(%rsi), %VMM(3)
	VPCMP	$4, (VEC_SIZE * 2)(%rdi), %VMM(3), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_2)

	VMOVU	(VEC_SIZE * 3)(%rsi), %VMM(4)
	VPCMP	$4, (VEC_SIZE * 3)(%rdi), %VMM(4), %k1
	KMOV	%k1, %VRCX
	test	%VRCX, %VRCX
	jnz	L(return_vec_3)

	/* Go to 4x VEC loop.  */
	cmpq	$(CHAR_PER_VEC * 8), %rdx
	ja	L(more_8x_vec)

	/* Handle remainder of size = 4 * VEC + 1 to 8 * VEC without any
	   branches.  */

	/* Load first two VEC from s2 before adjusting addresses.  */
	VMOVU	-(VEC_SIZE * 4)(%rsi, %rdx, CHAR_SIZE), %VMM(1)
	VMOVU	-(VEC_SIZE * 3)(%rsi, %rdx, CHAR_SIZE), %VMM(2)
	leaq	-(4 * VEC_SIZE)(%rdi, %rdx, CHAR_SIZE), %rdi
	leaq	-(4 * VEC_SIZE)(%rsi, %rdx, CHAR_SIZE), %rsi

	/* Wait to load from s1 until addressed adjust due to
	   unlamination of microfusion with complex address mode.  */

	/* vpxor will be all 0s if s1 and s2 are equal. Otherwise it
	   will have some 1s.  */
	vpxorq	(%rdi), %VMM(1), %VMM(1)
	vpxorq	(VEC_SIZE)(%rdi), %VMM(2), %VMM(2)

	VMOVU	(VEC_SIZE * 2)(%rsi), %VMM(3)
	vpxorq	(VEC_SIZE * 2)(%rdi), %VMM(3), %VMM(3)

	VMOVU	(VEC_SIZE * 3)(%rsi), %VMM(4)
	/* Ternary logic to xor (VEC_SIZE * 3)(%rdi) with VEC(4) while
	   oring with VEC(1). Result is stored in VEC(4).  */
	vpternlogd $0xde, (VEC_SIZE * 3)(%rdi), %VMM(1), %VMM(4)

	/* Or together VEC(2), VEC(3), and VEC(4) into VEC(4).  */
	vpternlogd $0xfe, %VMM(2), %VMM(3), %VMM(4)

	/* Test VEC(4) against itself. Store any CHAR mismatches in k1.  */
	VPTEST	%VMM(4), %VMM(4), %k1
	/* k1 must go to ecx for L(return_vec_0_1_2_3).  */
	KMOV	%k1, %VRCX
	test	%VRCX, %VRCX
	jnz	L(return_vec_0_1_2_3)
	/* NB: eax must be zero to reach here.  */
	ret


	.p2align 4,, 9
L(8x_end_return_vec_0_1_2_3):
	movq	%rdx, %rdi
L(8x_return_vec_0_1_2_3):
	ret
	addq	%rdi, %rsi
L(return_vec_0_1_2_3):
	VPTEST	%VMM(1), %VMM(1), %k0
	KMOV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_0)

	VPTEST	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_1)

	VPTEST	%VMM(3), %VMM(3), %k0
	KMOV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_2)
L(return_vec_3):
	/* bsf saves 1 byte from tzcnt. This keep L(return_vec_3) in one
	   fetch block and the entire L(*return_vec_0_1_2_3) in 1 cache
	   line.  */
	bsf	%VRCX, %VRCX
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE), %eax
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 3)(%rsi, %rcx, CHAR_SIZE), %eax
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	(VEC_SIZE * 3)(%rdi, %rcx), %eax
	movzbl	(VEC_SIZE * 3)(%rsi, %rcx), %ecx
	subl	%ecx, %eax
# endif
	ret


	.p2align 4,, 10
L(return_vec_1):
	/* bsf saves 1 byte over tzcnt and keeps L(return_vec_1) in one
	   fetch block.  */
	bsf	%VRAX, %VRAX
# ifdef USE_AS_WMEMCMP
	movl	VEC_SIZE(%rdi, %rax, CHAR_SIZE), %ecx
	xorl	%edx, %edx
	cmpl	VEC_SIZE(%rsi, %rax, CHAR_SIZE), %ecx
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	VEC_SIZE(%rsi, %rax), %ecx
	movzbl	VEC_SIZE(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif
	ret

	.p2align 4,, 10
L(return_vec_2):
	/* bsf saves 1 byte over tzcnt and keeps L(return_vec_2) in one
	   fetch block.  */
	bsf	%VRAX, %VRAX
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 2)(%rsi, %rax, CHAR_SIZE), %ecx
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	(VEC_SIZE * 2)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 2)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif
	ret

	.p2align 4,, 8
L(more_8x_vec):
	/* Set end of s1 in rdx.  */
	leaq	-(VEC_SIZE * 4)(%rdi, %rdx, CHAR_SIZE), %rdx
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
	vpxorq	VEC_SIZE(%rdi), %VMM(2), %VMM(2)
	VMOVU	(VEC_SIZE * 2)(%rsi, %rdi), %VMM(3)
	vpternlogd $0xde, (VEC_SIZE * 2)(%rdi), %VMM(1), %VMM(3)
	VMOVU	(VEC_SIZE * 3)(%rsi, %rdi), %VMM(4)
	vpternlogd $0xde, (VEC_SIZE * 3)(%rdi), %VMM(2), %VMM(4)
	VPTEST	%VMM(3), %VMM(3), %k2
	VPTEST	%VMM(4), %VMM(4), %k1
	KORTEST	%k1, %k2
	jnz	L(8x_return_vec_0_1_2_3)
	subq	$-(VEC_SIZE * 4), %rdi
	cmpq	%rdx, %rdi
	jb	L(loop_4x_vec)

	subq	%rdx, %rdi
	/* rdi has 4 * VEC_SIZE - remaining length.  */
	CMP_END	$(VEC_SIZE * 3), %edi
	jge	L(8x_last_1x_vec)
	/* Load regardless of branch.  */
	VMOVU	(VEC_SIZE * 2)(%rsi, %rdx), %VMM(3)
	cmpl	$(VEC_SIZE * 2 + CMP_END_OFFSET), %edi
	jge	L(8x_last_2x_vec)

	vpxorq	(VEC_SIZE * 2)(%rdx), %VMM(3), %VMM(3)

	VMOVU	(%rsi, %rdx), %VMM(1)
	vpxorq	(%rdx), %VMM(1), %VMM(1)

	VMOVU	VEC_SIZE(%rsi, %rdx), %VMM(2)
	vpxorq	VEC_SIZE(%rdx), %VMM(2), %VMM(2)
	VMOVU	(VEC_SIZE * 3)(%rsi, %rdx), %VMM(4)
	vpternlogd $0xde, (VEC_SIZE * 3)(%rdx), %VMM(1), %VMM(4)
	vpternlogd $0xfe, %VMM(2), %VMM(3), %VMM(4)
	VPTEST	%VMM(4), %VMM(4), %k1
	KMOV	%k1, %VRCX
	test	%VRCX, %VRCX
	jnz	L(8x_end_return_vec_0_1_2_3)
	/* NB: eax must be zero to reach here.  */
	ret

	/* Only entry is from L(more_8x_vec).  */
	.p2align 4,, 6
L(8x_last_2x_vec):
	VPCMP	$4, (VEC_SIZE * 2)(%rdx), %VMM(3), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(8x_return_vec_2)
	.p2align 4,, 5
L(8x_last_1x_vec):
	VMOVU	(VEC_SIZE * 3)(%rsi, %rdx), %VMM(1)
	VPCMP	$4, (VEC_SIZE * 3)(%rdx), %VMM(1), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(8x_return_vec_3)
	ret

# if VEC_SIZE == 32
	/* Not ideally aligned (at offset +9 bytes in fetch block) but
	   not aligning keeps it in the same cache line as
	   L(8x_last_1x/2x_vec) so likely worth it. As well, saves code
	   size.  */
	.p2align 4,, 4
# else
	.p2align 4,, 6
# endif
L(8x_return_vec_2):
	subq	$VEC_SIZE, %rdx
L(8x_return_vec_3):
	bsf	%VRAX, %VRAX
# ifdef USE_AS_WMEMCMP
	leaq	(LAST_VEC_OFFSET)(%rdx, %rax, CHAR_SIZE), %rax
	movl	(VEC_SIZE * 3 - LAST_VEC_OFFSET)(%rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 3 - LAST_VEC_OFFSET)(%rsi, %rax), %ecx
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
#  if LAST_VEC_OFFSET
	leaq	(LAST_VEC_OFFSET)(%rax, %rdx), %rax
#  else
	addq	%rdx, %rax
#  endif
	movzbl	(VEC_SIZE * 3 - LAST_VEC_OFFSET)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 3 - LAST_VEC_OFFSET)(%rax), %eax
	subl	%ecx, %eax
# endif
	ret

	.p2align 4,, 8
L(last_2x_vec):
	/* Check second to last VEC.  */
	VMOVU	-(VEC_SIZE * 2)(%rsi, %rdx, CHAR_SIZE), %VMM(1)
	VPCMP	$4, -(VEC_SIZE * 2)(%rdi, %rdx, CHAR_SIZE), %VMM(1), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_1_end)

	/* Check last VEC.  */
	.p2align 4
L(last_1x_vec):
	VMOVU	-(VEC_SIZE * 1)(%rsi, %rdx, CHAR_SIZE), %VMM(1)
	VPCMP	$4, -(VEC_SIZE * 1)(%rdi, %rdx, CHAR_SIZE), %VMM(1), %k1
	KMOV	%k1, %VRAX
	test	%VRAX, %VRAX
	jnz	L(return_vec_0_end)
	ret

# if VEC_SIZE == 64
	.p2align 4,, 4
# endif
	/* Don't align for evex256. Takes 2-fetch blocks either way and
	   aligning will cause code to spill into another cacheline.  */
L(return_vec_1_end):
	/* Use bsf to save code size. This is necessary to have
	   L(one_or_less) fit in aligning bytes between.  */
	bsf	%VRAX, %VRAX
	addl	%edx, %eax
# ifdef USE_AS_WMEMCMP
	movl	-(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %ecx
	xorl	%edx, %edx
	cmpl	-(VEC_SIZE * 2)(%rsi, %rax, CHAR_SIZE), %ecx
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	-(VEC_SIZE * 2)(%rsi, %rax), %ecx
	movzbl	-(VEC_SIZE * 2)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif
	ret

	/* Don't align. Takes 2-fetch blocks either way and aligning
	   will cause code to spill into another cacheline.  */
L(return_vec_0_end):
	tzcnt	%VRAX, %VRAX
	addl	%edx, %eax
# ifdef USE_AS_WMEMCMP
	movl	-VEC_SIZE(%rdi, %rax, CHAR_SIZE), %ecx
	xorl	%edx, %edx
	cmpl	-VEC_SIZE(%rsi, %rax, CHAR_SIZE), %ecx
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else
	movzbl	-VEC_SIZE(%rsi, %rax), %ecx
	movzbl	-VEC_SIZE(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif
	ret
	/* evex256: 1-byte until next cache line. evex512: 26-bytes
	   until next cache line.  */
END(MEMCMP)
#endif
