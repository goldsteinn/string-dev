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
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPMIN	vpminub
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
	decq	%rdx
	/* `dec` can macrofuse with `jl`. If the flag needs to become
	   `jb` replace `dec` with `sub`.  */
	jl	L(zero_len)

	vpxor	%xmm7, %xmm7, %xmm7
	movl	%esi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)
L(page_cross_continue):
	VMOVU	(%rsi), %ymm0
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx

	movq	%rdi, %rax

	cmpq	$(VEC_SIZE - 1), %rdx
	/* `jb` because length rdx is now length - 1.  */
	jbe	L(less_1x_vec)

	/* This may overset but thats fine because we still need to zero
	   fill.  */
	VMOVU	%ymm0, (%rdi)

	testl	%ecx, %ecx
	jnz	L(zfill)

	/* Align.  */
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

	cmpl	$(VEC_SIZE), %edx
	jb	L(ret_vec_x1_len)

	testl	%ecx, %ecx
	jnz	L(ret_vec_x1)

	VMOVA	VEC_SIZE(%rsi), %ymm2
	VMOVU	%ymm1, (%rdi)
	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	shlq	$32, %rcx
L(ret_vec_x1_len):
	tzcntq	%rcx, %rcx
	cmpl	%edx, %ecx
	ja	L(ret_vec_x1_len_no_zfill)
	/* Fall through (expectation) is copy len < buffer len.  */
	VMOVU	%ymm7, ((0)-(VEC_SIZE - 1))(%rdi, %rdx)
L(ret_vec_x1_len_no_zfill_mov):
	movl	%ecx, %edx
L(ret_vec_x1_len_no_zfill):
	VMOVU	((0)-(VEC_SIZE - 1))(%rsi, %rdx), %ymm1
	VMOVU	%ymm1, ((0)-(VEC_SIZE - 1))(%rdi, %rdx)
	VZEROUPPER_RETURN

	.p2align 4,, 6
L(ret_vec_x1):
	bsfl	%ecx, %ecx
	VMOVU	%ymm7, ((0)-(VEC_SIZE - 1))(%rdi, %rdx)
	subl	%ecx, %edx
	cmpl	$VEC_SIZE, %edx
	jb	L(ret_vec_x1_len_no_zfill_mov)
	VMOVU	%ymm1, (%rdi)
	VMOVU	%ymm7, (%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(more_2x_vec):
	VMOVU	%ymm1, (%rdi)
	testl	%ecx, %ecx
	/* Must fill at least 2x VEC.  */
	jnz	L(zfill_vec1)

	VMOVA	VEC_SIZE(%rsi), %ymm2
	VMOVU	%ymm2, VEC_SIZE(%rdi)
	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	/* Must fill at least 1x VEC.  */
	jnz	L(zfill_vec2)

	VMOVA	(VEC_SIZE * 2)(%rsi), %ymm3
	VPCMPEQ	%ymm3, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx

	/* Check if len is more 4x VEC. -1 because rdx is len - 1.  */
	cmpq	$(VEC_SIZE * 4 - 1), %rdx
	ja	L(more_4x_vec)

	cmpl	$(VEC_SIZE * 3), %edx
	jb	L(ret_vec_x3_len)

	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3)(%rsi), %ymm4
	VMOVU	%ymm3, (VEC_SIZE * 2)(%rdi)
	VPCMPEQ	%ymm4, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	shlq	$32, %rcx
L(ret_vec_x3_len):
	subl	$(VEC_SIZE * 2), %edx
	tzcntq	%rcx, %rcx
	cmpl	%edx, %ecx
	ja	L(ret_vec_x3_len_no_zfill)
	/* Fall through (expectation) is copy len < buffer len.  */
	VMOVU	%ymm7, ((VEC_SIZE * 2)-(VEC_SIZE - 1))(%rdi, %rdx)
L(ret_vec_x3_len_no_zfill_mov):
	movl	%ecx, %edx
L(ret_vec_x3_len_no_zfill):
	VMOVU	((VEC_SIZE * 2)-(VEC_SIZE - 1))(%rsi, %rdx), %ymm1
	VMOVU	%ymm1, ((VEC_SIZE * 2)-(VEC_SIZE - 1))(%rdi, %rdx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(ret_vec_x3):
	bsfl	%ecx, %ecx
	VMOVU	%ymm7, (-(VEC_SIZE - 1))(%rdi, %rdx)
	subl	%ecx, %edx
	cmpl	$(VEC_SIZE * 3), %edx
	jb	L(ret_vec_x3_len_no_zfill_mov)
	VMOVU	%ymm3, (VEC_SIZE * 2)(%rdi)
	VMOVU	%ymm7, (VEC_SIZE * 2)(%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(more_4x_vec):

	VMOVU	%ymm3, (VEC_SIZE * 2)(%rdi)
	testl	%ecx, %ecx
	jnz	L(zfill_vec3)

	VMOVA	(VEC_SIZE * 3)(%rsi), %ymm4
	VMOVU	%ymm4, (VEC_SIZE * 3)(%rdi)
	VPCMPEQ	%ymm4, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(zfill_vec4)

	subq	$-(VEC_SIZE * 4), %rdi
	subq	$-(VEC_SIZE * 4), %rsi
	addq	$-(VEC_SIZE * 4), %rdx
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
	subq	%rsi, %rdx
	VMOVU	%ymm0, (VEC_SIZE * 0 + 0)(%rdi)
	VPCMPEQ	%ymm0, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(zfill_vec1)

	VMOVU	%ymm1, (VEC_SIZE * 1 + 0)(%rdi)
	VPCMPEQ	%ymm1, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(zfill_vec2)

	VMOVU	%ymm2, (VEC_SIZE * 2 + 0)(%rdi)
	VPCMPEQ	%ymm2, %ymm7, %ymm6
	vpmovmskb %ymm6, %ecx
	testl	%ecx, %ecx
	jnz	L(zfill_vec3)

	VMOVU	%ymm3, (VEC_SIZE * 3 + 0)(%rdi)
	movl	%r8d, %ecx

	// Zfill more....


L(zfill_vec4):
    addq    $(VEC_SIZE * 2), %rdi
    subq    $(VEC_SIZE * 2), %rdx
L(zfill_vec2):
	shlq	$32, %rcx
L(zfill):
	bsfq	%rcx, %rcx
	addq	%rcx, %rdi
	subq	%rcx, %rdx
	cmpq	$VEC_SIZE, %rdx
	jb	L(zfill_less_vec_vzeroupper)

L(zfill_more_1x_vec):
	VMOVU	%ymm7, 1(%rdi)
	VMOVU	%ymm7, (1 - VEC_SIZE)(%rdi, %rdx)
	cmpq	$(VEC_SIZE * 2), %rdx
	jae	L(zfill_more_2x_vec)
L(zfill_done):
	VZEROUPPER_RETURN


L(zfill_vec3):
    addq    $(VEC_SIZE * 2), %rdi
    subq    $(VEC_SIZE * 2), %rdx
L(zfill_vec1):
	bsfl	%ecx, %ecx
	addq	%rcx, %rdi
	subq	%rcx, %rdx
	VMOVU	%ymm7, 1(%rdi)
	VMOVU	%ymm7, (1 - VEC_SIZE)(%rdi, %rdx)
	cmpq	$(VEC_SIZE * 2), %rdx
	jae	L(zfill_more_2x_vec)
	VZEROUPPER_RETURN

L(zfill_more_2x_vec):
	VMOVU	%ymm7, (1 - VEC_SIZE * 2)(%rdi, %rdx)
	VMOVU	%ymm7, (VEC_SIZE + 1)(%rdi)
	subq	$(VEC_SIZE * 4 - 1), %rdx
	jbe	L(zfill_done)

	addq	%rdi, %rdx
	VMOVU	%ymm7, (VEC_SIZE * 2 + 1)(%rdi)
	VMOVU	%ymm7, (VEC_SIZE * 3 + 1)(%rdi)


	VMOVU	%ymm7, (VEC_SIZE * 0 + 0)(%rdx)
	VMOVU	%ymm7, (VEC_SIZE * 1 + 0)(%rdx)

	subq	$-(VEC_SIZE * 4 + 1), %rdi
	cmpq	%rdi, %rdx
	jbe	L(zfill_done)

	andq	$-(VEC_SIZE), %rdi
	.p2align 4,, 12
L(zfill_loop_4x_vec):
	VMOVA	%ymm7, (VEC_SIZE * 0)(%rdi)
	VMOVA	%ymm7, (VEC_SIZE * 1)(%rdi)
	VMOVA	%ymm7, (VEC_SIZE * 2)(%rdi)
	VMOVA	%ymm7, (VEC_SIZE * 3)(%rdi)
	subq	$-(VEC_SIZE * 4), %rdi
	cmpq	%rdi, %rdx
	ja	L(zfill_loop_4x_vec)
	VZEROUPPER_RETURN


L(zfill_less_vec):
	bsfl	%ecx, %ecx
	subq	%rcx, %rdx
	addq	%rcx, %rdi
L(zfill_less_vec_vzeroupper):
	vzeroupper
	/* We are taking advantage of the fact that to be here we must
	   be writing null-term as (%rdi, %rcx) we have a byte of lee-
	   way for overwriting.  */
	cmpl	$16, %edx
	jb	L(zfill_less_16)
	VMOVU	%xmm7, (%rdi)
	VMOVU	%xmm7, -15(%rdi, %rdx)
	ret

	.p2align 4
L(zfill_less_16_setup):
	bsfl	%ecx, %ecx
	subq	%rcx, %rdx
	addq	%rcx, %rdi
	xorl	%ecx, %ecx
	.p2align 4,, 8
L(zfill_less_16):
	xorl	%ecx, %ecx

	cmpl	$8, %edx
	jb	L(zfill_less_8)
	movq	%rcx, (%rdi)
	movq	%rcx, -7(%rdi, %rdx)
	ret

	.p2align 4
L(zfill_less_8_setup):
	bsfl	%ecx, %ecx
	subq	%rcx, %rdx
	addq	%rcx, %rdi
	xorl	%ecx, %ecx
	.p2align 4,, 8
L(zfill_less_8):
	cmpl	$3, %edx
	jb	L(zfill_less_3)

	movl	%ecx, (%rdi)
	movl	%ecx, -3(%rdi, %rdx)
	ret

L(zfill_less_3):
	cmpl	$1, %edx
	jbe	L(zfill_1)
	movw	%cx, (%rdi)
L(zfill_1):
	movb	%cl, (%rdi, %rdx)
	ret

L(copy_1x):
	VMOVU	%ymm0, (%rdi)
	testl	%ecx, %ecx
	jnz	L(zfill_less_vec)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(less_1x_vec):
	je	L(copy_1x)
	cmpl	$16, %edx
	jae	L(copy_16_31)

	vzeroupper
	cmpl	$8, %edx
	jae	L(copy_8_15)

	cmpl	$3, %edx
	jb	L(copy_0_3)
	/* Overfill to avoid branches.  */
	movl	-3(%rsi, %rdx), %esi
	bzhil	%edx, %ecx, %r8d
	vmovd	%xmm0, (%rdi)
	movl	%esi, -3(%rdi, %rdx)
	/* Can't macrofuse anyways.  */
	jnz	L(zfill_less_8_setup)
	ret

	.p2align 4,, 4
L(copy_8_15):
	/* Overfill to avoid branches.  */
	movq	-7(%rsi, %rdx), %rsi
	bzhil	%edx, %ecx, %r8d
	vmovq	%xmm0, (%rdi)
	movq	%rsi, -7(%rdi, %rdx)
	/* Can't macrofuse anyways.  */
	jnz	L(zfill_less_16_setup)
	ret

	.p2align 4,, 4
L(copy_16_31):
	/* Overfill to avoid branches.  */
	VMOVU	-15(%rsi, %rdx), %xmm1
	bzhil	%edx, %ecx, %r8d
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -15(%rdi, %rdx)
	/* Can't macrofuse anyways.  */
	jnz	L(zfill_less_vec)
	VZEROUPPER_RETURN

	.p2align 4,, 4
L(copy_0_3):
	vmovd	%xmm0, %r8d
	testl	%edx, %edx
	jz	L(copy_1)
	bzhil	%edx, %ecx, %r9d
	movw	%r8w, (%rdi)
	jnz	L(zfill_from_1)
	movzbl	(%rsi, %rdx), %r8d
L(copy_1):
	movb	%r8b, (%rax, %rdx)
	ret


	.p2align 4,, 4
L(zfill_from_1):
	bsfl	%ecx, %ecx
	movb	$0, 1(%rdi, %rcx)
	movb	$0, (%rdi, %rdx)
	ret

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
	/* Optimizing aggressively for space as this is very cold code.
	   This saves 2x cache lines.  */

	shll	%ecx
	jz	L(page_cross_continue)
	bsfl	%ecx, %ecx
	rep	movsb
	VZEROUPPER_RETURN

L(page_cross_small):
	tzcntl	%ecx, %ecx
	cmpq	%rdx, %rcx
	cmova	%edx, %ecx
	incl	%ecx
	rep	movsb
	VZEROUPPER_RETURN

L(zero_len):
	incq	%rdx
	jnz	strcat_avx2_dev
	movq	%rdi, %rax
	ret

END(STRCPY)
#endif
