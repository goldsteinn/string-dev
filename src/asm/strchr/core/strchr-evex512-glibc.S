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

#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# define VEC_SIZE	64
# ifdef USE_AS_WCSCHR
#  define CHAR_REG	esi
#  define CHAR_SIZE	4
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
#  define VPMINU	vpminud
#  define VPTESTN	vptestnmd
# else
#  define CHAR_REG	sil
#  define CHAR_SIZE	1
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
#  define VPMINU	vpminub
#  define VPTESTN	vptestnmb
# endif

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# define XMM1	xmm17

# if VEC_SIZE == 64
#  define KMOV	kmovq
#  define KORTEST	kortestq
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
#  define KMOV	kmovd
#  define KORTEST	kortestd
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
ENTRY_P2ALIGN(STRCHR, 6)

	/* Broadcast CHAR to VMM0.  */
	VPBROADCAST %esi, %VMM0
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

	/* Compare [w]char for null, mask bit will be set for match.  */
	VMOVU	(%rdi), %VMM1

	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0

	KMOV	%k0, %RAX
# ifndef USE_AS_STRCHRNUL
	test	%RAX, %RAX
	jz	L(align_more)
	bsf	%RAX, %RAX
# else
	/* For strchnul, using bsf, if string is less than 64 byte,
	   entire logic will fit in 64 byte cache line and offset the
	   perf gap as compared to evex version.  Even though using bsf
	   as condition can save code size but it is not preferred for
	   conditional jump for 2 reason.  1) It's latency is 3. 2)
	   Unlike test, it can't be micro-fused with jump.  */
	bsf	%RAX, %RAX
	jz	L(align_more)
# endif

# ifdef USE_AS_WCSCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	add	%rdi, %rax
# endif
# ifndef USE_AS_STRCHRNUL
	cmp	(%rax), %CHAR_REG
	jne	L(zero)
# endif
	ret

# ifndef USE_AS_STRCHRNUL
L(zero):
	xorl	%eax, %eax
	ret
# endif

L(ret_vec_x2):
	subq	$-VEC_SIZE, %rax
L(ret_vec_x1):
	bsf	%RCX, %RCX
# ifdef USE_AS_WCSCHR
	leaq	(%rax, %rcx, CHAR_SIZE), %rax
# else
	add	%rcx, %rax
# endif

# ifndef USE_AS_STRCHRNUL
	cmp	(%rax), %CHAR_REG
	jne	L(zero)
# endif
	ret

L(align_more):
	leaq	VEC_SIZE(%rdi), %rax
	/* Align rax to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rax

	/* Loop unroll 4 times for 4 vector loop.  */
	VMOVA	(%rax), %VMM1
	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0

	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x1)

	VMOVA	VEC_SIZE(%rax), %VMM1
	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0

	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x2)

	VMOVA	(VEC_SIZE * 2)(%rax), %VMM1
	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3)(%rax), %VMM1
	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x4)

	/* Align address to VEC_SIZE * 4 for loop.  */
	andq	$-(VEC_SIZE * 4), %rax

	.p2align 4,, 11
L(loop):
	/* VPMINU and VPCMP combination provide better performance as
	   compared to alternative combinations.  */
	VMOVA	(VEC_SIZE * 4)(%rax), %VMM1
	VMOVA	(VEC_SIZE * 5)(%rax), %VMM2
	VMOVA	(VEC_SIZE * 6)(%rax), %VMM3
	VMOVA	(VEC_SIZE * 7)(%rax), %VMM4

	vpxorq	%VMM1, %VMM0, %VMM5
	VPMINU	%VMM5, %VMM1, %VMM1

	VPCMP	$4, %VMM0, %VMM2, %k1
	VPMINU	%VMM1, %VMM2, %VMM2{%k1}{z}

	VPCMP	$4, %VMM0, %VMM3, %k2
	VPMINU	%VMM2, %VMM3, %VMM3{%k2}{z}

	VPCMP	$4, %VMM0, %VMM4, %k3
	VPMINU	%VMM3, %VMM4, %VMM4{%k3}{z}

	VPTESTN	%VMM4, %VMM4, %k3

	subq	$-(VEC_SIZE * 4), %rax
	KORTEST	%k3, %k3
	jz	L(loop)

	VPTESTN	%VMM1, %VMM1, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x1)

	VPTESTN	%VMM2, %VMM2, %k0
	KMOV	%k0, %RCX
	/* At this point, if k1 is non zero, null char must be in the
	   second vector.  */
	test	%RCX, %RCX
	jnz	L(ret_vec_x2)

	VPTESTN	%VMM3, %VMM3, %k0
	KMOV	%k0, %RCX
	test	%RCX, %RCX
	jnz	L(ret_vec_x3)
	/* At this point null [w]char must be in the fourth vector so no
	   need to check.  */
	KMOV	%k3, %RCX

L(ret_vec_x4):
	bsf	%RCX, %RCX
	leaq	(VEC_SIZE * 3)(%rax, %rcx, CHAR_SIZE), %rax
# ifndef USE_AS_STRCHRNUL
	cmp	(%rax), %CHAR_REG
	jne	L(zero)
# endif
	ret

L(ret_vec_x3):
	bsf	%RCX, %RCX
	leaq	(VEC_SIZE * 2)(%rax, %rcx, CHAR_SIZE), %rax
# ifndef USE_AS_STRCHRNUL
	cmp	(%rax), %CHAR_REG
	jne	L(zero)
# endif
	ret

L(page_cross):
	movl	%eax, %ecx
# ifdef USE_AS_WCSCHR
	/* Calculate number of compare result bits to be skipped for
	   wide string alignment adjustment.  */
	andl	$(VEC_SIZE - 1), %ecx
	sarl	$2, %ecx
# endif
	/* ecx contains number of w[char] to be skipped as a result of
	   address alignment.  */
	xorq	%rdi, %rax
	VMOVA	(PAGE_SIZE - VEC_SIZE)(%rax), %VMM1
	vpxorq	%VMM1, %VMM0, %VMM2
	VPMINU	%VMM2, %VMM1, %VMM2
	VPTESTN	%VMM2, %VMM2, %k0
	KMOV	%k0, %RAX
	/* Ignore number of character for alignment adjustment.  */
	SHR	%cl, %RAX
	jz	L(align_more)

	bsf	%RAX, %RAX
# ifdef USE_AS_WCSCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif

# ifndef USE_AS_STRCHRNUL
	cmp	(%rax), %CHAR_REG
	jne	L(zero)
# endif
	ret

END(STRCHR)
#endif
