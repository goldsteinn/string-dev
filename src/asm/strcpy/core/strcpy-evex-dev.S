/* strcpy with AVX2
   Copyright (C) 2011-2022 Free Software Foundation, Inc.
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

# include "../../libc-defs/libc-evex-vecs.h"

# ifndef SECTION
#  define SECTION(p)	p##.evex
# endif


# ifdef USE_AS_WCSCPY
#  define VPMIN	vpminud
#  define VPTESTM	vptestmd
#  define VPCMPEQ	vpcmpeqd
#  define CHAR_SIZE	4
# else
#  define VPMIN	vpminub
#  define VPTESTM	vptestmb
#  define VPCMPEQ	vpcmpeqb
#  define CHAR_SIZE	1
# endif


# define VEC_SIZE	32
# define PAGE_SIZE	4096
# ifndef USE_AS_STPCPY
	// #  define USE_AS_STPCPY
# endif
# ifdef USE_AS_STPCPY
#  define END_REG	rax
# else
#  define END_REG	rdi, %rdx, CHAR_SIZE
# endif
# ifndef USE_AS_STRCAT
	// #  define USE_AS_STRCAT
# endif
# ifdef USE_AS_STRCAT
#  define PAGE_ALIGN_REG	ecx
# else
#  define PAGE_ALIGN_REG	eax
# endif


	.section SECTION(.text), "ax", @progbits
ENTRY(STRCPY)
	vpxorq	%VEC_xmm(7), %VEC_xmm(7), %VEC_xmm(7)

# ifdef USE_AS_STRCAT
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %rdx
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %rdx
	VPCMPEQ	(%rdx), %VEC(7), %k0
	kmovd	%k0, %ecx
#  ifdef USE_AS_WCSCPY
	subl	%edx, %edi
	shrl	$2, %edi
#  endif
	shrxl	%edi, %ecx, %ecx
#  ifdef USE_AS_WCSCPY
	movq	%rax, %rdi
#  endif
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%rdx), %VEC(7), %k0
	kmovd	%k0, %ecx
	leaq	(VEC_SIZE)(%rdx), %rdi
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%rdx), %VEC(7), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v1)

	orq	$(VEC_SIZE * 2 - 1), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(1)(%rdi), %VEC(0)
	VPMIN	(VEC_SIZE + 1)(%rdi), %VEC(0), %VEC(1)
	VPTESTM	%VEC(1), %VEC(1), %k0
	kmovd	%k0, %edx
	subq	$(VEC_SIZE * -2), %rdi
	testl	%edx, %edx
	jz	L(loop_2x_vec)

	addq	$(VEC_SIZE * -2 + 1), %rdi

	VPTESTM	%VEC(0), %VEC(0), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	movl	%edx, %ecx

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsfl	%ecx, %ecx
#  ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#  else
	addq	%rcx, %rdi
#  endif
# endif

	movl	%esi, %PAGE_ALIGN_REG
	andl	$(PAGE_SIZE - 1), %PAGE_ALIGN_REG
	cmpl	$(PAGE_SIZE - VEC_SIZE), %PAGE_ALIGN_REG
	ja	L(page_cross)
L(page_cross_continue):
# if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	movq	%rdi, %rax
# endif
	VMOVU	(%rsi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(more_1x_vec)

	xorl	%edx, %edx
	bsfl	%ecx, %edx
# ifdef USE_AS_STPCPY
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
# endif


# ifdef USE_AS_WCSCPY
	testb	$0xf, %cl
# else
	testw	%cx, %cx
# endif
	jz	L(copy_16_31)

# ifdef USE_AS_WCSCPY
	testb	$0x3, %cl
# else
	testb	%cl, %cl
# endif
	jz	L(copy_8_15)
# ifdef USE_AS_WCSCPY
	vmovd	%VEC_xmm(0), (%rdi)
	movl	$0, (%END_REG)
	ret
# else
	andl	$0x7, %ecx
	jz	L(copy_4_7)

	vmovd	%VEC_xmm(0), %ecx
	testl	%edx, %edx
	jz	L(set_null_term)
	movw	%cx, (%rdi)

	/* This only applies for stpcpy where we save a few bytes in
	   L(copy_...) because END_REG doesn't need an index.  */
	.p2align 4,, 1
L(set_null_term):
	movb	$0, (%END_REG)
	ret

	.p2align 4,, 12
L(copy_4_7):
	movl	-3(%rsi, %rdx), %ecx
	vmovd	%VEC_xmm(0), (%rdi)
	movl	%ecx, -3(%END_REG)
	ret
# endif

	.p2align 4,, 10
L(copy_16_31):
	/* Use xmm1 explicitly here as it won't induce a `vzeroupper`.
	 */
	vmovdqu	-(16 - CHAR_SIZE)(%rsi, %rdx), %xmm1
	VMOVU	%VEC_xmm(0), (%rdi)
	vmovdqu	%xmm1, -(16 - CHAR_SIZE)(%END_REG)
	ret
	.p2align 4,, 10
L(copy_8_15):
# ifdef USE_AS_WCSCPY
	movl	-(8 - CHAR_SIZE)(%rsi, %rdx), %ecx
# else
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx), %rcx
# endif
	vmovq	%VEC_xmm(0), (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%END_REG)
	ret

	.p2align 4,, 8
	.p2align 6,, 14
L(more_1x_vec):
# if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	VMOVU	%VEC(0), (%rdi)
# endif
	subq	%rsi, %rdi
	andq	$-(VEC_SIZE), %rsi
	addq	%rsi, %rdi
	VMOVA	(VEC_SIZE * 1)(%rsi), %VEC(1)
# if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	VMOVU	%VEC(0), (%rax)
# endif
	VPTESTM	%VEC(1), %VEC(1), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(more_2x_vec)
	.p2align 4,, 1
L(ret_vec_x1):
	bsfl	%ecx, %ecx
	VMOVU	(VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), (VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	VEC_SIZE(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 8
	.p2align 6,, 14
L(more_2x_vec):
	VMOVA	(VEC_SIZE * 2)(%rsi), %VEC(2)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)

	VPTESTM	%VEC(2), %VEC(2), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)

	VMOVA	(VEC_SIZE * 3)(%rsi), %VEC(3)
	VMOVU	%VEC(2), (VEC_SIZE * 2)(%rdi)

	VPTESTM	%VEC(3), %VEC(3), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jz	L(more_4x_vec)
	.p2align 4,, 1
L(ret_vec_x3):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 4
L(ret_vec_x2):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 2)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 2)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 2)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 4
L(ret_vec_x4):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
#  ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 4)(%rdi, %rcx, CHAR_SIZE), %rax
#  endif
	ret

	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rsi), %VEC(4)
	VMOVU	%VEC(3), (VEC_SIZE * 3)(%rdi)
	VPTESTM	%VEC(4), %VEC(4), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x4)

	VMOVU	%VEC(4), (VEC_SIZE * 4)(%rdi)

	subq	%rsi, %rdi
	subq	$-(VEC_SIZE * 5), %rsi
	andq	$-(VEC_SIZE * 4), %rsi


	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VEC(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VEC(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VEC(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VEC(3)

	VPMIN	%VEC(0), %VEC(1), %VEC(4)
	VPMIN	%VEC(2), %VEC(3), %VEC(6)
	VPMIN	%VEC(4), %VEC(6), %VEC(6)
	VPTESTM	%VEC(6), %VEC(6), %k0
	kmovd	%k0, %edx
	addq	%rsi, %rdi
	testl	%edx, %edx
	jnz	L(loop_4x_done)

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%VEC(0), (VEC_SIZE * 0 + 0)(%rdi)
	VMOVU	%VEC(1), (VEC_SIZE * 1 + 0)(%rdi)
	subq	$(VEC_SIZE * -4), %rsi
	VMOVU	%VEC(2), (VEC_SIZE * 2 + 0)(%rdi)
	VMOVU	%VEC(3), (VEC_SIZE * 3 + 0)(%rdi)


	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VEC(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VEC(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VEC(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VEC(3)

	VPMIN	%VEC(0), %VEC(1), %VEC(4)
	VPMIN	%VEC(2), %VEC(3), %VEC(6)
	VPMIN	%VEC(4), %VEC(6), %VEC(6)
	VPTESTM	%VEC(6), %VEC(6), %k0
	kmovd	%k0, %edx
	subq	$(VEC_SIZE * -4), %rdi
	testl	%edx, %edx
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPTESTM	%VEC(0), %VEC(0), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x0_end)
	VMOVU	%ymm0, (VEC_SIZE * 0 + 0)(%rdi)

	VPTESTM	%VEC(1), %VEC(1), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)
	VMOVU	%ymm1, (VEC_SIZE * 1 + 0)(%rdi)

	VPTESTM	%VEC(2), %VEC(2), %k0
	kmovd	%k0, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)
	VMOVU	%ymm2, (VEC_SIZE * 2 + 0)(%rdi)
	/* Place L(ret_vec_x4) here to save code size.  We get a
	   meaningfuly benefit doing this for stpcpy.  */
	bsfl	%edx, %edx
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3 + 0)(%rdi, %rdx, CHAR_SIZE), %rax
# endif
L(return_end):
	ret

	.p2align 4,, 1
L(ret_vec_x0_end):
	bsfl	%ecx, %ecx
	incl	%ecx
	VMOVU	(-(VEC_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), (-(VEC_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
#  ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rax
#  else
	addq	%rcx, %rdi
#  endif
# endif
	ret

	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
	movq	%rsi, %rdx
	andq	$(VEC_SIZE * -1), %rdx

	VPCMPEQ	(%rdx), %VEC(7), %k0
	kmovd	%k0, %ecx
# ifdef USE_AS_WCSCPY
	andl	$(VEC_SIZE - 1), %edx
	shrl	$2, %edx
# endif
	shrxl	%edx, %ecx, %ecx
# if 1
	/* Optimizing aggressively for space as this is very cold code.
	   This saves 2x cache lines.  */
	shll	$CHAR_SIZE, %ecx
	jz	L(page_cross_continue)
#  if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	movq	%rdi, %rax
#  endif
	bsfl	%ecx, %ecx
	rep	movsb
#  ifdef USE_AS_STPCPY
	leaq	-CHAR_SIZE(%rdi), %rax
#  endif

#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	ret
#  else
	jmp	L(return_end)
	/* 0 bytes until next cache line.  */
#  endif


# else
	testl	%ecx, %ecx
	jz	L(page_cross_continue)
#  ifndef USE_AS_STRCAT
	xorl	%edx, %edx
#  endif
	/* Dependency on rdi must already have been satisfied.  */
	bsfl	%ecx, %edx
#  ifdef USE_AS_STPCPY
	leaq	(%rdi, %rdx), %rax
#  elif !defined USE_AS_STRCAT
	movq	%rdi, %rax
#  endif


	testw	%cx, %cx
	jz	L(page_cross_copy_16_31)

	testb	%cl, %cl
	jz	L(page_cross_copy_8_15)

	andl	$0x7, %ecx
	jz	L(page_cross_copy_4_7)

	testl	%edx, %edx
	jz	L(page_cross_set_null_term)
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
L(page_cross_set_null_term):
	movb	$0, (%END_REG)
	ret


	.p2align 4,, 4
L(page_cross_copy_4_7):
	movl	(%rsi), %ecx
	movl	-3(%rsi, %rdx), %esi
	movl	%ecx, (%rdi)
	movl	%esi, -3(%END_REG)
	ret
	.p2align 4,, 4
L(page_cross_copy_8_15):
	movq	(%rsi), %rcx
	movq	-7(%rsi, %rdx), %rsi
	movq	%rcx, (%rdi)
	movq	%rsi, -7(%END_REG)
	ret


	.p2align 4,, 3
L(page_cross_copy_16_31):
	VMOVU	(%rsi), %xmm0
	VMOVU	-15(%rsi, %rdx), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -15(%END_REG)
	ret

# endif



END(STRCPY)
#endif
