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

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

# ifndef SECTION
#  define SECTION(p)	p##.avx
# endif


# ifdef USE_AS_WCSCPY
#  define VPCMPEQ	vpcmpeqd
#  define VPMIN	vpminud
#  define CHAR_SIZE	4
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPMIN	vpminub
#  define CHAR_SIZE	1
# endif

# define VMOVU	vmovdqu
# define VMOVA	vmovdqa

# define VEC_SIZE	32
# define PAGE_SIZE	4096
# ifndef USE_AS_STPCPY
	// #  define USE_AS_STPCPY
# endif
# ifdef USE_AS_STPCPY
#  define END_REG	rax
# else
#  define END_REG	rdi, %rdx
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
	vpxor	%xmm7, %xmm7, %xmm7

# ifdef USE_AS_STRCAT
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %rdx
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %rdx
	VPCMPEQ	(%rdx), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	shrxl	%edi, %ecx, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%rdx), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	leaq	(VEC_SIZE)(%rdx), %rdi
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%rdx), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v1)

	orq	$(VEC_SIZE * 2 - 1), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(1)(%rdi), %ymm0
	VPMIN	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	VPCMPEQ	%ymm1, %ymm7, %ymm1
	vpmovmskb %ymm1, %edx
	subq	$(VEC_SIZE * -2), %rdi
	testl	%edx, %edx
	jz	L(loop_2x_vec)

	addq	$(VEC_SIZE * -2 + 1), %rdi

	VPCMPEQ	%ymm0, %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	movl	%edx, %ecx

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsfl	%ecx, %ecx
	addq	%rcx, %rdi
# endif

	movl	%esi, %PAGE_ALIGN_REG
	andl	$(PAGE_SIZE - 1), %PAGE_ALIGN_REG
	cmpl	$(PAGE_SIZE - VEC_SIZE), %PAGE_ALIGN_REG
	ja	L(page_cross)
L(page_cross_continue):
# if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	movq	%rdi, %rax
# endif
	VMOVU	(%rsi), %ymm0
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx

	testl	%ecx, %ecx
	jz	L(more_1x_vec)

	vzeroupper

	xorl	%edx, %edx
	bsfl	%ecx, %edx
# ifdef USE_AS_STPCPY
	leaq	(%rdi, %rdx), %rax
# endif

	testw	%cx, %cx
	jz	L(copy_16_31)

	testb	%cl, %cl
	jz	L(copy_8_15)
# ifdef USE_AS_WCSCPY
	vmovd	%xmm0, (%rdi)
	movl	$0, (%END_REG)
	ret
# else
	andl	$0x7, %ecx
	jz	L(copy_4_7)

	testl	%edx, %edx
	jz	L(set_null_term)
    vmovd	%xmm0, %ecx
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
	vmovd	%xmm0, (%rdi)
	movl	%ecx, -3(%END_REG)
	ret
# endif

	.p2align 4,, 10
L(copy_16_31):
	VMOVU	-(16 - CHAR_SIZE)(%rsi, %rdx), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -(16 - CHAR_SIZE)(%END_REG)
	ret
	.p2align 4,, 10
L(copy_8_15):
# ifdef USE_AS_WCSCPY
	movl	-(8 - CHAR_SIZE)(%rsi, %rdx), %ecx
# else
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx), %rcx
# endif
	vmovq	%xmm0, (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%END_REG)
	ret

	.p2align 4,, 8
	.p2align 6,, 14
L(more_1x_vec):
# if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	VMOVU	%ymm0, (%rdi)
# endif
	subq	%rsi, %rdi
	orq	$(VEC_SIZE - 1), %rsi
	addq	%rsi, %rdi
	VMOVA	1(%rsi), %ymm1
# if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	VMOVU	%ymm0, (%rax)
# endif
	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jz	L(more_2x_vec)
	.p2align 4,, 1
L(ret_vec_x1):
	bsfl	%ecx, %ecx
	VMOVU	(1 -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, (1 -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
# ifdef USE_AS_STPCPY
	leaq	1(%rcx, %rdi), %rax
# endif
	VZEROUPPER_RETURN

	.p2align 4,, 8
	.p2align 6,, 14
L(more_2x_vec):
	VMOVA	(VEC_SIZE + 1)(%rsi), %ymm2
	VMOVU	%ymm1, 1(%rdi)

	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)

	VMOVA	(VEC_SIZE * 2 + 1)(%rsi), %ymm3
	VMOVU	%ymm2, (VEC_SIZE + 1)(%rdi)

	VPCMPEQ	%ymm3, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jz	L(more_4x_vec)
	.p2align 4,, 1
L(ret_vec_x3):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 2 + 1)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 2 + 1)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 2 + 1)(%rcx, %rdi), %rax
# endif
	VZEROUPPER_RETURN

	.p2align 4,, 4
L(ret_vec_x2):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE + 1)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE + 1)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 1 + 1)(%rcx, %rdi), %rax
# endif
	VZEROUPPER_RETURN
# if !defined USE_AS_STPCPY
	.p2align 4,, 4
L(ret_vec_x4):
	bsfl	%edx, %edx
	VMOVU	((VEC_SIZE * 3 + 1)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 3 + 1)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx)
#  ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3 + 1)(%rdx, %rdi), %rax
#  endif
	VZEROUPPER_RETURN
# endif

	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	VMOVA	(VEC_SIZE * 3 + 1)(%rsi), %ymm4
	VMOVU	%ymm3, (VEC_SIZE * 2 + 1)(%rdi)
	VPCMPEQ	%ymm4, %ymm7, %ymm6
	vpmovmskb %ymm6, %edx
	testl	%edx, %edx
	jnz	L(ret_vec_x4)

	VMOVU	%ymm4, (VEC_SIZE * 3 + 1)(%rdi)

	subq	%rsi, %rdi
	incq	%rsi
	orq	$(VEC_SIZE * 4 - 1), %rsi

	VMOVA	(VEC_SIZE * 0 + 1)(%rsi), %ymm0
	VMOVA	(VEC_SIZE * 1 + 1)(%rsi), %ymm1
	VMOVA	(VEC_SIZE * 2 + 1)(%rsi), %ymm2
	VMOVA	(VEC_SIZE * 3 + 1)(%rsi), %ymm3

	VPMIN	%ymm0, %ymm1, %ymm4
	VPMIN	%ymm2, %ymm3, %ymm6
	VPMIN	%ymm4, %ymm6, %ymm6
	VPCMPEQ	%ymm6, %ymm7, %ymm6
	vpmovmskb %ymm6, %edx
	addq	%rsi, %rdi


	testl	%edx, %edx
	jnz	L(loop_4x_done)

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%ymm0, (VEC_SIZE * 0 + 1)(%rdi)
	VMOVU	%ymm1, (VEC_SIZE * 1 + 1)(%rdi)
	subq	$(VEC_SIZE * -4), %rsi
	VMOVU	%ymm2, (VEC_SIZE * 2 + 1)(%rdi)
	VMOVU	%ymm3, (VEC_SIZE * 3 + 1)(%rdi)


	VMOVA	(VEC_SIZE * 0 + 1)(%rsi), %ymm0
	VMOVA	(VEC_SIZE * 1 + 1)(%rsi), %ymm1
	VMOVA	(VEC_SIZE * 2 + 1)(%rsi), %ymm2
	VMOVA	(VEC_SIZE * 3 + 1)(%rsi), %ymm3

	VPMIN	%ymm0, %ymm1, %ymm4
	VPMIN	%ymm2, %ymm3, %ymm6
	VPMIN	%ymm4, %ymm6, %ymm6
	VPCMPEQ	%ymm6, %ymm7, %ymm6

	vpmovmskb %ymm6, %edx
	subq	$(VEC_SIZE * -4), %rdi
	testl	%edx, %edx
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)
	VMOVU	%ymm0, (VEC_SIZE * 0 + 1)(%rdi)

	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)
	VMOVU	%ymm1, (VEC_SIZE * 1 + 1)(%rdi)

	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)
	VMOVU	%ymm2, (VEC_SIZE * 2 + 1)(%rdi)
	/* Place L(ret_vec_x4) here to save code size.  We get a
	   meaningfuly benefit doing this for stpcpy.  */
# if defined USE_AS_STPCPY
L(ret_vec_x4):
# endif
	bsfl	%edx, %edx
	VMOVU	((VEC_SIZE * 3 + 1)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 3 + 1)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3 + 1)(%rdx, %rdi), %rax
# endif
L(return_end):
	VZEROUPPER_RETURN

	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
	movq	%rsi, %rcx
	andq	$(VEC_SIZE * -1), %rcx

	VPCMPEQ	(%rcx), %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	shrxl	%esi, %ecx, %ecx
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
	VZEROUPPER_RETURN
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
	vzeroupper

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
