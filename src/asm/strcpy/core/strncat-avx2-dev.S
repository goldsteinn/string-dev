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
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
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
	// # define USE_AS_STRNCAT
# if defined USE_AS_STRNCAT || defined USE_AS_STRNCPY
#  define USE_AS_STRN
# endif
# if defined USE_AS_STRLCAT || defined USE_AS_STRLCPY
#  define USE_AS_STRL
# endif

# if defined USE_AS_STRN || defined USE_AS_STRL
#  define HAS_LEN	1
# else
#  define HAS_LEN	0
# endif


# ifdef USE_AS_STRCAT
#  define PAGE_ALIGN_REG	ecx
#  if HAS_LEN
#   define ALIGNED_SRC_REG	r8
#  else
#   define ALIGNED_SRC_REG	rdx
#  endif
# else
#  define PAGE_ALIGN_REG	eax
# endif
# if HAS_LEN
#  define TMP_REG32	r8d
#  define TMP_REG64	r8

# else
#  define TMP_REG32	edx
#  define TMP_REG64	rdx

# endif

	.section SECTION(.text), "ax", @progbits
ENTRY(STRCPY)
	/* Filter zero length strings and very long strings.  Zero
	   length strings just return, very long strings are handled
	   either by using the non-length variant which has lower
	   overhead or causing a segfault (strncpy).  */
# ifdef USE_AS_WCSCPY
	decq	%rdx
	movq	%rdx, %rax
	shr	$60, %rax
	jnz	L(zero_len)
	salq	$2, %rdx
# else
	decq	%rdx
	/* `dec` can macrofuse with `jl`. If the flag needs to become
	   `jb` replace `dec` with `sub`.  */
	jl	L(zero_len)
# endif

	vpxor	%xmm7, %xmm7, %xmm7
# ifdef USE_AS_STRCAT
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %r8
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %r8
	VPCMPEQ	(%r8), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	shrxl	%edi, %ecx, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%r8), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	leaq	(VEC_SIZE)(%r8), %rdi
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%r8), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v1)

	orq	$(VEC_SIZE * 2 - 1), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(1)(%rdi), %ymm0
	VPMIN	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	VPCMPEQ	%ymm1, %ymm7, %ymm1
	vpmovmskb %ymm1, %TMP_REG32
	subq	$(VEC_SIZE * -2), %rdi
	testl	%TMP_REG32, %TMP_REG32
	jz	L(loop_2x_vec)

	addq	$(VEC_SIZE * -2 + 1), %rdi

	VPCMPEQ	%ymm0, %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	movl	%TMP_REG32, %ecx

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
	VMOVU	(%rsi), %ymm0
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx

	cmpq	$VEC_SIZE, %rdx
	/* `jb` because length rdx is now length - 1.  */
	jb	L(less_1x_vec)

	testl	%ecx, %ecx
	jz	L(more_1x_vec)

	/* Hoist this to save code size.  */
	vzeroupper
	bsfl	%ecx, %edx

	testw	%cx, %cx
	jz	L(copy_16_31)

	.p2align 4,, 2
L(copy_less_16):
	testb	%cl, %cl
	jz	L(copy_8_15)

# ifndef USE_AS_WCSCPY
	andl	$0x7, %ecx
	jz	L(copy_4_7)

	vmovd	%xmm0, %ecx
	testl	%edx, %edx
	jz	L(set_null_term)
	movw	%cx, (%rdi)
	movzbl	(%rsi, %rdx), %ecx
#  ifdef USE_AS_STPCPY
	/* This only applies for stpcpy where we save a few bytes in
	   L(copy_...) because END_REG doesn't need an index.  */
	.p2align 4,, 1
#  endif
L(set_null_term):
	movb	%cl, (%END_REG)
	ret

	.p2align 4,, 11
L(copy_4_7):
# endif
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx), %ecx
	vmovd	%xmm0, (%rdi)
	movl	%ecx, -(4 - CHAR_SIZE)(%END_REG)
	ret


	.p2align 4,, 4
L(less_1x_vec):
	btsl	%edx, %ecx
	COND_VZEROUPPER
	/* edx already a dependency.  */
	bsfl	%ecx, %edx
	testw	%cx, %cx
	jnz	L(copy_less_16)

	.p2align 4,, 10
L(copy_16_31):
	VMOVU	-(16 - CHAR_SIZE)(%rsi, %rdx), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -(16 - CHAR_SIZE)(%END_REG)
	ret

	.p2align 4,, 10
L(copy_8_15):
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx), %rcx
	vmovq	%xmm0, (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%END_REG)
	ret

	.p2align 4,, 8
	.p2align 6,, 14
L(more_1x_vec):
# if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	VMOVU	%ymm0, (%rdi)
# endif
	addq	%rsi, %rdx
	subq	%rsi, %rdi
	orq	$(VEC_SIZE - 1), %rsi
	incq	%rsi
	addq	%rsi, %rdi
L(loop_last_4x_vec):
	subq	%rsi, %rdx
L(last_4x_vec):
	VMOVA	0(%rsi), %ymm1
	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx


	cmpq	$(VEC_SIZE * 2), %rdx
	jae	L(more_2x_vec)
L(last_2x_vec):
	cmpl	$(VEC_SIZE), %edx
	jb	L(ret_vec_x1_len)

	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)

	VMOVA	(VEC_SIZE + 0)(%rsi), %ymm2
	VMOVU	%ymm1, 0(%rdi)

	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
L(ret_vec_x2_len):
	btsl	%edx, %ecx
	.p2align 4,, 3
L(ret_vec_x2):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN


	.p2align 4,, 12
L(ret_vec_x1_len):
	btsl	%edx, %ecx
L(ret_vec_x1):
	bsfl	%ecx, %ecx
	VMOVU	(0 -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, (0 -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(ret_vec_x3_len):
	btsl	%edx, %ecx
L(ret_vec_x3):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 2 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 2 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
	.p2align 6,, 14
L(more_2x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)

	VMOVA	(VEC_SIZE + 0)(%rsi), %ymm2
	VMOVU	%ymm1, 0(%rdi)

	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)


	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %ymm3
	VMOVU	%ymm2, (VEC_SIZE + 0)(%rdi)

	VPCMPEQ	%ymm3, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx

	addq	$(VEC_SIZE * -4), %rdx
	jbe	L(more_4x_vec)

	cmpl	$((VEC_SIZE * 3 - 1)-(VEC_SIZE * 4)), %edx
	jle	L(ret_vec_x3_len)

L(last_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %ymm4
	VMOVU	%ymm3, (VEC_SIZE * 2 + 0)(%rdi)
	VPCMPEQ	%ymm4, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
L(ret_vec_x4_len):
	btsl	%edx, %ecx
L(ret_vec_x4):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN




	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %ymm4
	VMOVU	%ymm3, (VEC_SIZE * 2 + 0)(%rdi)
	VPCMPEQ	%ymm4, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x4)

	VMOVU	%ymm4, (VEC_SIZE * 3 + 0)(%rdi)

	subq	$-(VEC_SIZE * 4), %rdi
	subq	$-(VEC_SIZE * 4), %rsi
	/* Recheck length before aligning.  */
	cmpq	$(VEC_SIZE * 4 - 1), %rdx
	jbe	L(last_4x_vec)

	addq	%rsi, %rdx
	subq	%rsi, %rdi
	andq	$(VEC_SIZE * -4), %rsi

	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %ymm0
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %ymm1
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %ymm2
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %ymm3

	VPMIN	%ymm0, %ymm1, %ymm4
	VPMIN	%ymm2, %ymm3, %ymm6
	VPMIN	%ymm4, %ymm6, %ymm6
	VPCMPEQ	%ymm6, %ymm7, %ymm6
	vpmovmskb %ymm6, %r8d
	addq	%rsi, %rdi
	testl	%r8d, %r8d
	jnz	L(loop_4x_done)

	leaq	-(VEC_SIZE * 4 - 1)(%rdx), %r9
	// movq    %rdx, %r9
	// andq    $(VEC_SIZE * -4), %r9

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%ymm0, (VEC_SIZE * 0 + 0)(%rdi)
	VMOVU	%ymm1, (VEC_SIZE * 1 + 0)(%rdi)
	subq	$(VEC_SIZE * -4), %rsi
	VMOVU	%ymm2, (VEC_SIZE * 2 + 0)(%rdi)
	VMOVU	%ymm3, (VEC_SIZE * 3 + 0)(%rdi)

	subq	$(VEC_SIZE * -4), %rdi
	cmpq	%rsi, %r9
	jbe	L(loop_last_4x_vec)

	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %ymm0
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %ymm1
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %ymm2
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %ymm3

	VPMIN	%ymm0, %ymm1, %ymm4
	VPMIN	%ymm2, %ymm3, %ymm6
	VPMIN	%ymm4, %ymm6, %ymm6
	VPCMPEQ	%ymm6, %ymm7, %ymm6

	vpmovmskb %ymm6, %r8d

	testl	%r8d, %r8d
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)
	VMOVU	%ymm0, (VEC_SIZE * 0 + 0)(%rdi)

	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)
	VMOVU	%ymm1, (VEC_SIZE * 1 + 0)(%rdi)

	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)
	VMOVU	%ymm2, (VEC_SIZE * 2 + 0)(%rdi)
	/* Place L(ret_vec_x4) here to save code size.  We get a
	   meaningfuly benefit doing this for stpcpy.  */
# if defined USE_AS_STPCPY
L(ret_vec_x4):
# endif
	bsfl	%r8d, %r8d
	VMOVU	((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %r8), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %r8)
L(return_end):
	VZEROUPPER_RETURN

	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
	movq	%rsi, %r8
	andq	$(VEC_SIZE * -1), %r8

	VPCMPEQ	(%r8), %ymm7, %ymm6

	vpmovmskb %ymm6, %ecx
	shrxl	%esi, %ecx, %ecx

	subl	%esi, %r8d
	andl	$(VEC_SIZE - 1), %r8d
	cmpq	%r8, %rdx
	jb	L(page_cross_small)
# if 1
	/* Optimizing aggressively for space as this is very cold code.
	   This saves 2x cache lines.  */

	shll	$CHAR_SIZE, %ecx
	jz	L(page_cross_continue)
	bsfl	%ecx, %ecx
	rep	movsb
	VZEROUPPER_RETURN

L(page_cross_small):
	tzcntl	%ecx, %ecx
	cmpq	%rdx, %rcx
	cmova	%edx, %ecx
#  if USE_AS_WCSCPY
	addl	$4, %ecx
#  else
	incl	%ecx
#  endif
	rep	movsb
	VZEROUPPER_RETURN

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

L(zero_len):
	incq	%rdx
# ifdef USE_AS_WCSCPY
	jnz	wcscat_avx2_dev
# else
	jnz	strcat_avx2_dev
# endif
	movq	%rdi, %rax
	ret


END(STRCPY)
#endif
