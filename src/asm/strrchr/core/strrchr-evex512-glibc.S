/* Placeholder function, not used by any processor at the moment.
   Copyright (C) 2022 Free Software Foundation, Inc.
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

/* UNUSED. Exists purely as reference implementation.  */
#ifndef VEC_SIZE
# define VEC_SIZE	64
#endif
#include "../../libc-asm-common.h"
#if ISA_SHOULD_BUILD (4)


# ifdef USE_AS_WCSRCHR
#  define CHAR_SIZE	4
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
#  define VPMINU	vpminud
#  define VPTESTN	vptestnmd
# else
#  define CHAR_SIZE	1
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
#  define VPMINU	vpminub
#  define VPTESTN	vptestnmb
# endif

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

# if VEC_SIZE == 64
#  define BLSMSK	blsmskq
#  define BSR	bsrq
#  define KMOV	kmovq
#  define KOR	korq
#  define KORTEST	kortestq
#  define R8	r8
#  define RAX	rax
#  define RCX	rcx
#  define RDX	rdx
#  define SHR	shrq
#  define TEXTSUFFIX	evex512
#  define VMM0	zmm16
#  define VMM1	zmm17
#  define VMM2	zmm18
#  define VMM3	zmm19
#  define VMM4	zmm20
#  define VMM5	zmm21
#  define VMOVA	vmovdqa64
#  define VMOVU	vmovdqu64

# elif VEC_SIZE == 32
	/* Currently Unused.  */
#  define BLSMSK	blsmskl
#  define BSR	bsrl
#  define KMOV	kmovd
#  define KOR	kord
#  define KORTEST	kortestd
#  define R8	r8d
#  define RAX	eax
#  define RCX	ecx
#  define RDX	edx
#  define SHR	shrl
#  define TEXTSUFFIX	evex256
#  define VMM0	ymm16
#  define VMM1	ymm17
#  define VMM2	ymm18
#  define VMM3	ymm19
#  define VMM4	ymm20
#  define VMM5	ymm21
#  define VMOVA	vmovdqa32
#  define VMOVU	vmovdqu32
# endif

	.section .text.TEXTSUFFIX, "ax", @progbits
	/* Aligning entry point to 64 byte, provides better performance
	   for one vector length string.  */
ENTRY_P2ALIGN(STRRCHR, 6)

	/* Broadcast CHAR to VMM0.  */
	VPBROADCAST %esi, %VMM0
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

L(page_cross_continue):
	/* Compare [w]char for null, mask bit will be set for match.  */
	VMOVU	(%rdi), %VMM1

	VPTESTN	%VMM1, %VMM1, %k1
	KMOV	%k1, %RCX
	test	%RCX, %RCX
	jz	L(align_more)

	VPCMP	$0, %VMM1, %VMM0, %k0
	KMOV	%k0, %RAX
	BLSMSK	%RCX, %RCX
	and	%RCX, %RAX
	jz	L(ret)

	BSR	%RAX, %RAX
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	add	%rdi, %rax
# endif
L(ret):
	ret

L(vector_x2_end):
	VPCMP	$0, %VMM2, %VMM0, %k2
	KMOV	%k2, %RAX
	BLSMSK	%RCX, %RCX
	and	%RCX, %RAX
	jz	L(vector_x1_ret)

	BSR	%RAX, %RAX
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	/* Check the first vector at very last to look for match.  */
L(vector_x1_ret):
	VPCMP	$0, %VMM1, %VMM0, %k2
	KMOV	%k2, %RAX
	test	%RAX, %RAX
	jz	L(ret)

	BSR	%RAX, %RAX
# ifdef USE_AS_WCSRCHR
	leaq	(%rsi, %rax, CHAR_SIZE), %rax
# else
	add	%rsi, %rax
# endif
	ret

L(align_more):
	/* Zero r8 to store match result.  */
	xorq	%r8, %r8
	/* Save pointer of first vector, in case if no match found.  */
	movq	%rdi, %rsi
	/* Align pointer to vector size.  */
	andq	$-VEC_SIZE, %rdi
	/* Loop unroll 2 times for 2 vector loop.  */
	VMOVA	(VEC_SIZE)(%rdi), %VMM2
	VPTESTN	%VMM2, %VMM2, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(vector_x2_end)

	/* Save pointer of second vector, in case if no match found.  */
	movq	%rdi, %r9
	/* Align address to VEC_SIZE * 2 for loop.  */
	andq	$-(VEC_SIZE * 2), %rdi

	.p2align 4,, 11
L(loop):
	/* 2 vector loop, as it provide better performance as compared
	   to 4 vector loop.  */
	VMOVA	(VEC_SIZE * 2)(%rdi), %VMM3
	VMOVA	(VEC_SIZE * 3)(%rdi), %VMM4
	VPCMP	$0, %VMM3, %VMM0, %k1
	VPCMP	$0, %VMM4, %VMM0, %k2
	VPMINU	%VMM3, %VMM4, %VMM5
	VPTESTN	%VMM5, %VMM5, %k0
	KOR	%k1, %k2, %k3
	subq	$-(VEC_SIZE * 2), %rdi
	/* If k0 and k3 zero, match and end of string not found.  */
	KORTEST	%k0, %k3
	jz	L(loop)
	/* If k0 is non zero, end of string found.  */
	KORTEST	%k0, %k0
	jnz	L(endloop)

	/* A match found, it need to be stored in r8 before loop
	   continue.  */
	/* Check second vector first.  */
	KMOV	%k2, %RDX
	test	%RDX, %RDX
	jz	L(loop_vec_x3_ret)

	BSR	%RDX, %RDX
	leaq	(VEC_SIZE)(%rdi, %rdx, CHAR_SIZE), %r8
	jmp	L(loop)

	/* If second vector doesn't have match, first vector must have
	   match.  */
L(loop_vec_x3_ret):
	KMOV	%k1, %R8
	BSR	%R8, %R8
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %r8, CHAR_SIZE), %r8
# else
	add	%rdi, %r8
# endif
	jmp	L(loop)

L(endloop):
	/* Check if string end in first loop vector.  */
	VPTESTN	%VMM3, %VMM3, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(vector_x3_end)

	/* Check if it has match in first loop vector.  */
	KMOV	%k1, %RAX
	test	%RAX, %RAX
	jz	L(vector_x4_end)

	BSR	%RAX, %RAX
	leaq	(%rdi, %rax, CHAR_SIZE), %r8

	/* String must end in second loop vector.  */
L(vector_x4_end):
	VPTESTN	%VMM4, %VMM4, %k0
	KMOV	%k0, %RCX
	KMOV	%k2, %RAX
	BLSMSK	%RCX, %RCX
	/* Check if it has match in second loop vector.  */
	and	%RCX, %RAX
	jz	L(check_last_match)

	BSR	%RAX, %RAX
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	/* String end in first loop vector.  */
L(vector_x3_end):
	KMOV	%k1, %RAX
	BLSMSK	%RCX, %RCX
	/* Check if it has match in second loop vector.  */
	and	%RCX, %RAX
	jz	L(check_last_match)

	BSR	%RAX, %RAX
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
	ret

	/* No match in first and second loop vector.  */
L(check_last_match):
	/* Check if any match recorded in r8.  */
	test	%r8, %r8
	jz	L(vector_x2_ret)
	movq	%r8, %rax
	ret

	/* No match recorded in r8. Check the second saved vector in
	   begining.  */
L(vector_x2_ret):
	VPCMP	$0, %VMM2, %VMM0, %k2
	KMOV	%k2, %RAX
	test	%RAX, %RAX
	jz	L(vector_x1_ret)

	/* Match found in the second saved vector.  */
	BSR	%RAX, %RAX
	leaq	(VEC_SIZE)(%r9, %rax, CHAR_SIZE), %rax
	ret

L(page_cross):
	movl	%eax, %ecx
# ifdef USE_AS_WCSRCHR
	/* Calculate number of compare result bits to be skipped for
	   wide string alignment adjustment.  */
	andl	$(VEC_SIZE - 1), %ecx
	sarl	$2, %ecx
# endif
	/* ecx contains number of w[char] to be skipped as a result of
	   address alignment.  */
	xorq	%rdi, %rax
	VMOVA	(PAGE_SIZE - VEC_SIZE)(%rax), %VMM1

	VPTESTN	%VMM1, %VMM1, %k1
	KMOV	%k1, %RAX
	SHR	%cl, %RAX
	jz	L(page_cross_continue)
	VPCMP	$0, %VMM1, %VMM0, %k0
	KMOV	%k0, %RDX
	SHR	%cl, %RDX
	BLSMSK	%RAX, %RAX
	and	%RDX, %RAX
	jz	L(ret)
	BSR	%RAX, %RAX
# ifdef USE_AS_WCSRCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	add	%rdi, %rax
# endif

	ret
END(STRRCHR)
#endif
