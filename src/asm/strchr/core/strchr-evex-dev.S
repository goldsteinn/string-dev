/* strchr/strchrnul optimized with 256-bit EVEX instructions.
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
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif
#if ISA_SHOULD_BUILD (4)


# ifndef STRCHR
#  define STRCHR	__strchr_evex
# endif

# define VMOVU	vmovdqu64
# define VMOVA	vmovdqa64

# ifdef USE_AS_WCSCHR
#  define REG_WIDTH	32
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define VPTESTN	vptestnmd
#  define VPMINU	vpminud
#  define CHAR_REG	esi
#  define SHIFT_REG	ecx
#  define CHAR_SIZE	4
# else
#  define REG_WIDTH	VEC_SIZE
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
#  define VPCMPEQ	vpcmpeqb
#  define VPTESTN	vptestnmb
#  define VPMINU	vpminub
#  define CHAR_REG	sil
#  define SHIFT_REG	edx
#  define CHAR_SIZE	1
# endif

# define VMATCH	VEC(0)

# include "../../libc-defs/libc-reg-macros.h"

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

	.section .text.evex, "ax", @progbits
ENTRY_P2ALIGN(STRCHR, 6)
	/* Broadcast CHAR to VEC_0.  */
	VPBROADCAST %esi, %VMATCH
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	/* Check if we cross page boundary with one vector load.
	   Otherwise it is safe to use an unaligned load.  */
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes. Search for both CHAR and the
	   null bytes.  */
	VMOVU	(%rdi), %VEC(1)

	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
	bsf	%VGPR(rax), %VGPR(rax)
# ifndef USE_AS_STRCHRNUL
	/* Found CHAR or the null byte.  */
	cmp	(%rdi, %rax, CHAR_SIZE), %CHAR_REG
	/* NB: Use a branch instead of cmovcc here. The expectation is
	   that with strchr the user will branch based on input being
	   null. Since this branch will be 100% predictive of the user
	   branch a branch miss here should save what otherwise would
	   be branch miss in the user code. Otherwise using a branch 1)
	   saves code size and 2) is faster in highly predictable
	   environments.  */
	jne	L(zero)
# endif
# ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret

# ifndef USE_AS_STRCHRNUL
L(zero):
	xorl	%eax, %eax
	ret
# endif





	.p2align 4,, 2
L(first_vec_x3):
	subq	$-(VEC_SIZE * 2), %rdi
L(first_vec_x1):
	/* Use bsf here to save 1-byte keeping keeping the block in 1x
	   fetch block. eax guranteed non-zero.  */
	bsf	%VGPR(rax), %VGPR(rax)
# ifndef USE_AS_STRCHRNUL
	/* Found CHAR or the null byte.  */
	cmp	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %CHAR_REG
	jne	L(zero)

# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 2
L(first_vec_x4):
	subq	$-(VEC_SIZE * 2), %rdi
L(first_vec_x2):
# ifndef USE_AS_STRCHRNUL
	/* Check to see if first match was CHAR (k0) or null (k1).  */
	kmovV	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	kmovV	%k1, %VGPR(rcx)
	/* bzhil will not be 0 if first match was null.  */
	bzhi	%VGPR(rax), %VGPR(rcx), %VGPR(rcx)
	jne	L(zero)
# else
	/* Combine CHAR and null matches.  */
	korV	%k0, %k1, %k0
	kmovV	%k0, %VGPR(rax)
	bsf	%VGPR(rax), %VGPR(rax)
# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4
L(aligned_more):

	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi
L(cross_page_continue):
	/* Check the next 4 * VEC_SIZE. Only one VEC_SIZE at a time
	   since data is only aligned to VEC_SIZE. Use two alternating
	   methods for checking VEC to balance latency and port
	   contention.  */

	/* This method has higher latency but has better port
	   distribution.  */
	VMOVA	(VEC_SIZE)(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	/* This method has higher latency but has better port
	   distribution.  */
	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(1)
	/* Each bit in K0 represents a CHAR in VEC_1.  */
	VPCMPEQ	%VEC(1), %VMATCH, %k0
	/* Each bit in K1 represents a CHAR in VEC_1.  */
	VPTESTN	%VEC(1), %VEC(1), %k1
	kortestV %k0, %k1
	jnz	L(first_vec_x2)

	VMOVA	(VEC_SIZE * 3)(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	/* Each bit in K0 represents a CHAR in VEC_1.  */
	VPCMPEQ	%VEC(1), %VMATCH, %k0
	/* Each bit in K1 represents a CHAR in VEC_1.  */
	VPTESTN	%VEC(1), %VEC(1), %k1
	kortestV %k0, %k1
	jnz	L(first_vec_x4)

	/* Align data to VEC_SIZE * 4 for the loop.  */
	addq	$VEC_SIZE, %rdi
	andq	$-(VEC_SIZE * 4), %rdi

	.p2align 4
L(loop_4x_vec):
	/* Check 4x VEC at a time. No penalty to imm32 offset with evex
	   encoding.  */
	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	VMOVA	(VEC_SIZE * 5)(%rdi), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VEC(3)
	VMOVA	(VEC_SIZE * 7)(%rdi), %VEC(4)

	/* For VEC_1 and VEC_3 use xor to set the CHARs matching esi to
	   zero.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(5)
	/* For VEC_2 and VEC_4 cmp not equals to CHAR and store result
	   in k register. Its possible to save either 1 or 2
	   instructions using cmp no equals method for either VEC_1 or
	   VEC_1 and VEC_3 respectively but bottleneck on p5 makes it
	   not worth it.  */
	VPCMP	$4, %VMATCH, %VEC(2), %k2
	vpxorq	%VEC(3), %VMATCH, %VEC(7)
	VPCMP	$4, %VMATCH, %VEC(4), %k4

	/* Use min to select all zeros from either xor or end of
	   string).  */
	VPMINU	%VEC(1), %VEC(5), %VEC(1)
	VPMINU	%VEC(3), %VEC(7), %VEC(3)

	/* Use min + zeromask to select for zeros. Since k2 and k4 will
	   have 0 as positions that matched with CHAR which will set
	   zero in the corresponding destination bytes in VEC_2 /
	   VEC_4.  */
	VPMINU	%VEC(1), %VEC(2), %VEC(2){%k2}{z}
	VPMINU	%VEC(3), %VEC(4), %VEC(4)
	VPMINU	%VEC(2), %VEC(4), %VEC(4){%k4}{z}

	VPTESTN	%VEC(4), %VEC(4), %k1
	kmovV	%k1, %VGPR(rcx)
	subq	$-(VEC_SIZE * 4), %rdi
	test	%VGPR(rcx), %VGPR(rcx)
	jz	L(loop_4x_vec)

	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x1)

	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x2)

	VPTESTN	%VEC(3), %VEC(3), %k0
	kmovV	%k0, %VGPR(rax)
	/* Combine VEC_3 matches (eax) with VEC_4 matches (ecx).  */
# ifdef USE_AS_WCSCHR
	sall	$8, %ecx
	orl	%ecx, %eax
	bsf	%VGPR(rax), %VGPR(rax)
# else
	salq	$32, %rcx
	orq	%rcx, %rax
	bsfq	%rax, %rax
# endif
# ifndef USE_AS_STRCHRNUL
	/* Check if match was CHAR or null.  */
	cmp	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %CHAR_REG
	jne	L(zero_end)
# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 8
L(last_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif

# ifndef USE_AS_STRCHRNUL
	/* Check if match was null.  */
	cmp	(%rax), %CHAR_REG
	jne	L(zero_end)
# endif

	ret

	.p2align 4,, 8
L(last_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
# ifndef USE_AS_STRCHRNUL
	/* Check if match was null.  */
	cmp	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %CHAR_REG
	jne	L(zero_end)
# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	/* Cold case for crossing page with first load.  */
	.p2align 4,, 8
L(cross_page_boundary):
	movq	%rdi, %rdx
	/* Align rdi.  */
	andq	$-VEC_SIZE, %rdi
	VMOVA	(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	/* Remove the leading bits.  */
# ifdef USE_AS_WCSCHR
	movl	%edx, %SHIFT_REG
	/* NB: Divide shift count by 4 since each bit in K1 represent 4
	   bytes.  */
	sarl	$2, %SHIFT_REG
	andl	$(CHAR_PER_VEC - 1), %SHIFT_REG
# endif
	sarx	%VGPR(SHIFT_REG), %VGPR(rax), %VGPR(rax)
	/* If eax is zero continue.  */
	test	%VGPR(rax), %VGPR(rax)
	jz	L(cross_page_continue)
	bsf	%VGPR(rax), %VGPR(rax)

# ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rdx, %rax, CHAR_SIZE), %rax
# else
	addq	%rdx, %rax
# endif
# ifndef USE_AS_STRCHRNUL
	/* Check to see if match was CHAR or null.  */
	cmp	(%rax), %CHAR_REG
	je	L(cross_page_ret)
L(zero_end):
	xorl	%eax, %eax
L(cross_page_ret):
# endif
	ret

END(STRCHR)
#endif
