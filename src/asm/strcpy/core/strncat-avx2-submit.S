/* strncat with AVX2
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
#define STRNCAT STRCPY
#include <isa-level.h>

#if ISA_SHOULD_BUILD (3)

# include <sysdep.h>

# ifndef VEC_SIZE
#  include "x86-avx2-vecs.h"
# endif

# ifndef STRNCAT
#  define STRNCAT	__strncat_avx2
# endif


	/* Use movsb in page cross case to save code size.  */
# define USE_MOVSB_IN_PAGE_CROSS	1

# ifdef USE_AS_WCSCPY
#  define VPCMPEQ	vpcmpeqd
#  define VPMIN	vpminud
#  define CHAR_SIZE	4
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPMIN	vpminub
#  define CHAR_SIZE	1
# endif

# include "strncpy-or-cat-overflow-def.h"

# define PAGE_SIZE	4096

# define VZERO	VMM(7)
# define VZERO_128	VMM_128(7)

	.section SECTION(.text), "ax", @progbits
ENTRY(STRNCAT)
	/* Filter zero length strings and very long strings.  Zero
	   length strings just return, very long strings are handled by
	   using the non-length variant {wcs|str}cat.  */
# ifdef USE_AS_WCSCPY
	decq	%rdx
	movq	%rdx, %rcx
	shr	$56, %rcx
	jnz	L(zero_len)
	salq	$2, %rdx
# else
	decq	%rdx
	/* `dec` can macrofuse with `jl`. If the flag needs to become
	   `jb` replace `dec` with `sub`.  */
	jl	L(zero_len)
# endif
	movq	%rdi, %rax
	vpxor	%VZERO_128, %VZERO_128, %VZERO_128

# include "strcat-strlen-avx2.S"

	movl	%esi, %ecx
	andl	$(PAGE_SIZE - 1), %ecx
	cmpl	$(PAGE_SIZE - VEC_SIZE), %ecx
	ja	L(page_cross)
L(page_cross_continue):
	VMOVU	(%rsi), %VMM(0)
	VPCMPEQ	%VMM(0), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx

	cmpq	$VEC_SIZE, %rdx
	/* `jb` because length rdx is now length - 1.  */
	jb	L(less_1x_vec)

	testl	%ecx, %ecx
	jz	L(more_1x_vec)

	/* Hoist this to save code size.  */
	COND_VZEROUPPER
	bsfl	%ecx, %edx

	/* Use mask bits in rcx to detect which copy we need. If the low
	   mask is zero then there must be a bit set in the upper half.
	   I.e if ecx != 0 and cx == 0, then match must be upper 16
	   bits so we use L(copy_16_31).  */
	testw	%cx, %cx
	jz	L(copy_16_31)

	.p2align 4,, 2
L(copy_less_16):
	testb	%cl, %cl
	jz	L(copy_8_15)

# ifndef USE_AS_WCSCPY
	testb	$0x7, %cl
	jz	L(copy_4_7)

	vmovd	%xmm0, %ecx
	testl	%edx, %edx
	jz	L(set_null_term)
	movw	%cx, (%rdi)
	movzbl	(%rsi, %rdx), %ecx
L(set_null_term):
	movb	%cl, (%rdi, %rdx)
	ret

	.p2align 4,, 11
L(copy_4_7):
# endif
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx), %ecx
	vmovd	%xmm0, (%rdi)
	movl	%ecx, -(4 - CHAR_SIZE)(%rdi, %rdx)
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
	VMOVU	%xmm1, -(16 - CHAR_SIZE)(%rdi, %rdx)
	ret

	.p2align 4,, 10
L(copy_8_15):
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx), %rcx
	vmovq	%xmm0, (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%rdi, %rdx)
	ret

	.p2align 4,, 8
	.p2align 6,, 14
L(more_1x_vec):
	VMOVU	%VMM(0), (%rdi)

	/* Align rsi (src) and just rdx/rdi (length/dst).  */
	addq	%rsi, %rdx
	subq	%rsi, %rdi
	orq	$(VEC_SIZE - 1), %rsi
	incq	%rsi
	addq	%rsi, %rdi
L(loop_last_4x_vec):
	subq	%rsi, %rdx
L(last_4x_vec):
	VMOVA	0(%rsi), %VMM(1)
	VPCMPEQ	%VMM(1), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx


	cmpq	$(VEC_SIZE * 2), %rdx
	jae	L(more_2x_vec)
L(last_2x_vec):
	tzcnt	%ecx, %ecx
	cmpl	%ecx, %edx
	jb	L(ret_vec_x1_len)

	cmpl	$VEC_SIZE, %ecx
	jnz	L(ret_vec_x1)

	VMOVA	(VEC_SIZE + 0)(%rsi), %VMM(2)
	VMOVU	%VMM(1), 0(%rdi)

	VPCMPEQ	%VMM(2), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
L(ret_vec_x2_len):
	/* btsl will automatically mask lower VEC_SIZE - 1 bits from
	   edx.  */
	btsl	%edx, %ecx
	.p2align 4,, 3
L(ret_vec_x2):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %VMM(1)
	VMOVU	%VMM(1), ((VEC_SIZE + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
L(return_vzeroupper):
	ZERO_UPPER_VEC_REGISTERS_RETURN


	.p2align 4,, 12
L(ret_vec_x1_len):
	movl	%edx, %ecx
L(ret_vec_x1):
	VMOVU	(0 -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %VMM(1)
	VMOVU	%VMM(1), (0 -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
L(ret_vec_x3_len):
	btsl	%edx, %ecx
L(ret_vec_x3):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 2 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %VMM(1)
	VMOVU	%VMM(1), ((VEC_SIZE * 2 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN

	.p2align 4,, 8
	.p2align 6,, 14
L(more_2x_vec):
	/* L(ret_vec_x1) expects ecx to have position of first match so
	   test with bsf.  */
	bsfl	%ecx, %ecx
	jnz	L(ret_vec_x1)

	VMOVA	(VEC_SIZE + 0)(%rsi), %VMM(2)
	VMOVU	%VMM(1), 0(%rdi)

	VPCMPEQ	%VMM(2), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)


	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(3)
	VMOVU	%VMM(2), (VEC_SIZE + 0)(%rdi)

	VPCMPEQ	%VMM(3), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx

	/* Check if length is greater than 4x VEC.  */
	addq	$(VEC_SIZE * -4), %rdx
	jbe	L(more_4x_vec)

	/* Check if length was between [VEC_SIZE * 2 + 1, VEC_SIZE * 3].
	 */
	cmpl	$((VEC_SIZE * 3 - 1)-(VEC_SIZE * 4)), %edx
	jle	L(ret_vec_x3_len)

L(last_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(4)
	VMOVU	%VMM(3), (VEC_SIZE * 2 + 0)(%rdi)
	VPCMPEQ	%VMM(4), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
L(ret_vec_x4_len):
	btsl	%edx, %ecx
L(ret_vec_x4):
	bsfl	%ecx, %ecx
	VMOVU	((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx), %VMM(1)
	VMOVU	%VMM(1), ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx)
	VZEROUPPER_RETURN




	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)

	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(4)
	VMOVU	%VMM(3), (VEC_SIZE * 2 + 0)(%rdi)
	VPCMPEQ	%VMM(4), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x4)

	VMOVU	%VMM(4), (VEC_SIZE * 3 + 0)(%rdi)

	subq	$-(VEC_SIZE * 4), %rdi
	subq	$-(VEC_SIZE * 4), %rsi
	/* Recheck length before aligning.  */
	cmpq	$(VEC_SIZE * 4 - 1), %rdx
	jbe	L(last_4x_vec)

	/* Align rsi (src) and just rdx/rdi (length/dst).  */
	addq	%rsi, %rdx
	subq	%rsi, %rdi
	andq	$(VEC_SIZE * -4), %rsi

	/* Do first half of loop ahead of time so loop can just start by
	   storing.  */
	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(3)

	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPMIN	%VMM(4), %VMM(6), %VMM(6)
	VPCMPEQ	%VMM(6), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %r8d
	addq	%rsi, %rdi
	testl	%r8d, %r8d
	jnz	L(loop_4x_done)

	/* Use r9 for end of region before handling last 4x VEC
	   specially.  */
	leaq	-(VEC_SIZE * 4 - CHAR_SIZE)(%rdx), %r9

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%VMM(0), (VEC_SIZE * 0 + 0)(%rdi)
	VMOVU	%VMM(1), (VEC_SIZE * 1 + 0)(%rdi)
	subq	$(VEC_SIZE * -4), %rsi
	VMOVU	%VMM(2), (VEC_SIZE * 2 + 0)(%rdi)
	VMOVU	%VMM(3), (VEC_SIZE * 3 + 0)(%rdi)

	subq	$(VEC_SIZE * -4), %rdi
	cmpq	%rsi, %r9
	jbe	L(loop_last_4x_vec)

	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(3)

	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPMIN	%VMM(4), %VMM(6), %VMM(6)
	VPCMPEQ	%VMM(6), %VZERO, %VMM(6)

	vpmovmskb %VMM(6), %r8d

	testl	%r8d, %r8d
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPCMPEQ	%VMM(0), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
	/* L(ret_vec_x1) expects ecx to have position of first match so
	   test with bsf.  */
	bsfl	%ecx, %ecx
	jnz	L(ret_vec_x1)
	VMOVU	%VMM(0), (VEC_SIZE * 0 + 0)(%rdi)

	VPCMPEQ	%VMM(1), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x2)
	VMOVU	%VMM(1), (VEC_SIZE * 1 + 0)(%rdi)

	VPCMPEQ	%VMM(2), %VZERO, %VMM(6)
	vpmovmskb %VMM(6), %ecx
	testl	%ecx, %ecx
	jnz	L(ret_vec_x3)
	VMOVU	%VMM(2), (VEC_SIZE * 2 + 0)(%rdi)
	bsfl	%r8d, %r8d
	VMOVU	((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rsi, %r8), %VMM(1)
	VMOVU	%VMM(1), ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %r8)
L(return_end):
	VZEROUPPER_RETURN

	.p2align 4,, 4
L(page_cross):
	movq	%rsi, %r8
	andq	$(VEC_SIZE * -1), %r8

	VPCMPEQ	(%r8), %VZERO, %VMM(6)

	vpmovmskb %VMM(6), %ecx
	shrxl	%esi, %ecx, %ecx

	subl	%esi, %r8d
	andl	$(VEC_SIZE - 1), %r8d
	cmpq	%r8, %rdx
	jb	L(page_cross_small)
# if USE_MOVSB_IN_PAGE_CROSS
	/* Optimizing more aggressively for space as this is very cold
	   code. This saves 2x cache lines.  */

	/* This adds once to the later result which will get correct
	   copy bounds. NB: this can never zero-out a non-zero RCX as
	   to be in the page cross case rsi cannot be aligned and we
	   already right-shift rcx by the misalignment.  */
	shll	$CHAR_SIZE, %ecx
	jz	L(page_cross_continue)
	bsfl	%ecx, %ecx
	rep	movsb
	VZEROUPPER_RETURN

L(page_cross_small):
	tzcntl	%ecx, %ecx
	cmpq	%rdx, %rcx
	cmova	%edx, %ecx
#  ifdef USE_AS_WCSCPY
	addl	$CHAR_SIZE, %ecx
#  else
	incl	%ecx
#  endif
	rep	movsb
	VZEROUPPER_RETURN

# else
	testl	%ecx, %ecx
	jz	L(page_cross_continue)
	xorl	%edx, %edx


	/* Traditional copy case, essentially same as used in non-page-
	   cross case but since we can't reuse VMM(0) we need twice as
	   many loads from rsi.  */
	bsfl	%ecx, %edx
	COND_VZEROUPPER

	testw	%cx, %cx
	jz	L(page_cross_copy_16_31)

	testb	%cl, %cl
	jz	L(page_cross_copy_8_15)

	testb	$0x7, %cl
	jz	L(page_cross_copy_4_7)

	testl	%edx, %edx
	jz	L(page_cross_set_null_term)
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
L(page_cross_set_null_term):
	movb	$0, (%rdi, %rdx)
	ret


	.p2align 4,, 4
L(page_cross_copy_4_7):
	movl	(%rsi), %ecx
	movl	-3(%rsi, %rdx), %esi
	movl	%ecx, (%rdi)
	movl	%esi, -3(%rdi, %rdx)
	ret
	.p2align 4,, 4
L(page_cross_copy_8_15):
	movq	(%rsi), %rcx
	movq	-7(%rsi, %rdx), %rsi
	movq	%rcx, (%rdi)
	movq	%rsi, -7(%rdi, %rdx)
	ret


	.p2align 4,, 3
L(page_cross_copy_16_31):
	VMOVU	(%rsi), %xmm0
	VMOVU	-15(%rsi, %rdx), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -15(%rdi, %rdx)
	ret

# endif

L(zero_len):
	incq	%rdx
	jnz	OVERFLOW_STRCAT
	movq	%rdi, %rax
	ret


END(STRNCAT)
#endif
