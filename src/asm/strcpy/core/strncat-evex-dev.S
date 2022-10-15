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
# ifndef VEC_SIZE
#  include "../../libc-defs/libc-evex512-vecs.h"
# endif
# ifndef SECTION
#  define SECTION(p)	p##.evex
# endif


# ifdef USE_AS_WCSCPY
#  define REG_WIDTH	32
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPCMPEQ	vpcmpeqd
#  define CHAR_SIZE	4
# else
#  define REG_WIDTH	VEC_SIZE
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPCMPEQ	vpcmpeqb
#  define CHAR_SIZE	1
# endif

# include "../../libc-defs/libc-reg-macros.h"


# define PAGE_SIZE	4096

# define PAGE_ALIGN_REG	eax

# define VZERO	VMM(7)
# define VZERO_128	VMM_128(7)

# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

	.section SECTION(.text), "ax", @progbits
ENTRY(STRCPY)

	decq	%rdx
	jl	L(zero_len)

	vpxorq	%VZERO_128, %VZERO_128, %VZERO_128
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %r8
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %r8
	VPCMPEQ	(%r8), %VZERO, %k0
	KMOV	%k0, %VRCX
# ifdef USE_AS_WCSCPY
	subl	%edx, %edi
	shrl	$2, %edi
# endif
	shrx	%VRDI, %VRCX, %VRCX
# ifdef USE_AS_WCSCPY
	movq	%rax, %rdi
# endif
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%r8), %VZERO, %k0
	KMOV	%k0, %VRCX
	leaq	(VEC_SIZE)(%r8), %rdi
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%r8), %VZERO, %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v1)

	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(VEC_SIZE * 2)(%rdi), %VMM(0)
	VPMIN	(VEC_SIZE * 3)(%rdi), %VMM(0), %VMM(1)
	VPTESTN	%VMM(1), %VMM(1), %k0
	KMOV	%k0, %VR8
	subq	$(VEC_SIZE * -2), %rdi
	test	%VR8, %VR8
	jz	L(loop_2x_vec)


	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	mov	%VR8, %VRCX

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsf	%VRCX, %VRCX
# ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
# else
	addq	%rcx, %rdi
# endif
#endif



	movl	%esi, %PAGE_ALIGN_REG
	andl	$(PAGE_SIZE - 1), %PAGE_ALIGN_REG
	cmpl	$(PAGE_SIZE - VEC_SIZE), %PAGE_ALIGN_REG
	ja	L(page_cross)
L(page_cross_continue):
	VMOVU	(%rsi), %VMM(0)
	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX

	tzcnt	%VRCX, %VRCX
	cmpq	%rcx, %rdx
	jb	L(less_1x_vec)

	cmpl	$VEC_SIZE, %ecx
	je	L(more_1x_vec)

	leal	1(%rcx), %edx

L(less_1x_vec):
#if VEC_SIZE == 64
	cmpl	$(32 / CHAR_SIZE), %edx
	ja	L(copy_32_63)
#endif

	cmpl	$(16 / CHAR_SIZE), %edx
	ja	L(copy_16_31)


	cmpl	$(8 / CHAR_SIZE), %edx
	ja	L(copy_8_15)

#ifdef USE_AS_WCSCPY
	vmovd	%VMM_128(0), (%rdi)
	movl	$0, (%rdi, %rdx)
	ret
#else

	cmpl	$4, %edx
	ja	L(copy_4_7)

	movzbl	(%rsi, %rdx), %ecx
	test	%edx, %edx
	je	L(set_null_term)

	/* NB: make this `vmovw` if support for AVX512-FP16 is added.
	 */
	movzwl	(%rsi), %esi
	movw	%si, (%rdi)


	.p2align 4,, 1
L(set_null_term):
	movb	%cl, (%rdi, %rdx)
	ret

# if VEC_SIZE == 64
	.p2align 4,, 6
L(copy_32_63):
	VMOVU	-(32 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %VMM_256(1)
	VMOVU	%VMM_256(0), (%rdi)
	VMOVU	%VMM_256(1), -(32 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret
# endif


	.p2align 4,, 6
L(copy_16_31):
	/* Use xmm1 explicitly here as it won't require a `vzeroupper`
	   and will save code size.  */
	vmovdqu	-(16 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %xmm1
	VMOVU	%VMM_128(0), (%rdi)
	vmovdqu	%xmm1, -(16 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret

	.p2align 4,, 2
L(copy_8_15):
# ifdef USE_AS_WCSCPY
	movl	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %ecx
# else
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %rcx
# endif
	vmovq	%VMM_128(0), (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret



# ifndef USE_AS_WCSCPY
	.p2align 4,, 12
L(copy_4_7):
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %ecx
	vmovd	%VMM_128(0), (%rdi)
	movl	%ecx, -(4 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret
# endif



	.p2align 4,, 8
	.p2align 6,, 14
L(more_1x_vec):
	VMOVU	%VMM(0), (%rdi)

	leaq	(VEC_SIZE * -1)(%rsi, %rdx), %rdx
	subq	%rsi, %rdi
	andq	$-(VEC_SIZE), %rsi
	addq	%rsi, %rdi
	subq	%rsi, %rdx

	VMOVA	(VEC_SIZE * 1)(%rsi), %VMM(1)
	VPTESTN	%VMM(1), %VMM(1), %k0
	KMOV	%k0, %VRCX

	cmpq	$(VEC_SIZE * 2), %rdx
	jbe	L(more_2x_vec)

L(last_2x_vec):
	tzcnt	%VRCX, %VRCX
	cmpl	%ecx, %edx
	jb	L(ret_vec_x1_len)

	cmpl	$VEC_SIZE, %ecx
	jne	L(ret_vec_x1)

	VMOVA	(VEC_SIZE * 2)(%rsi), %VMM(2)
	VMOVU	%VMM(1), (VEC_SIZE * 1)(%rdi)
	VPTESTN	%VMM(2), %VMM(1), %k0
	KMOV	%k0, %VRCX

	bts	%VRDX, %VRCX
L(ret_vec_x2):    
	bsf	%VRCX, %VRCX
	VMOVU	(VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), (VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
	ret

L(ret_vec_x1_len):
	movl	%edx, %ecx
L(ret_vec_x1):
	VMOVU	(-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), (-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
	ret
L(zero_len):
    ud2

	.p2align 4,, 7
	.p2align 6,, 14
L(more_2x_vec):
	bsf	%VRCX, %VRCX
	jnz	L(ret_vec_x1)

    
	VMOVA	(VEC_SIZE * 2)(%rsi), %VMM(2)
	VMOVU	%VMM(1), (VEC_SIZE * 1)(%rdi)
	VPTESTN	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x2)

	VMOVA	(VEC_SIZE * 3)(%rsi), %VMM(3)
	VMOVU	%VMM(2), (VEC_SIZE * 2)(%rdi)
	VPTESTN	%VMM(3), %VMM(3), %k0
	KMOV	%k0, %VRCX

    cmpq    $(CHAR_PER_VEC * 4 - 1), %rdx
    jae L(more_4x_vec)

    addl    $(CHAR_PER_VEC * -2), %edx
    
	tzcnt	%VRCX, %VRCX
    cmpl	%ecx, %edx
	jb	L(ret_vec_x3_len)

	cmpl	$VEC_SIZE, %ecx
	jne	L(ret_vec_x3)

    
    

	.p2align 4,, 1
L(ret_vec_x3_len):
	movl	%edx, %ecx    
L(ret_vec_x3):
	bsf	%VRCX, %VRCX
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)

	ret


	.p2align 4,, 6
L(ret_vec_x4):
	bsf	%VRCX, %VRCX
	VMOVU	((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)

	ret

	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rsi), %VMM(4)
	VMOVU	%VMM(3), (VEC_SIZE * 3)(%rdi)
	VPTESTN	%VMM(4), %VMM(4), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x4)

	VMOVU	%VMM(4), (VEC_SIZE * 4)(%rdi)

	subq	%rsi, %rdi
	subq	$-(VEC_SIZE * 5), %rsi
	andq	$-(VEC_SIZE * 4), %rsi


	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(3)

	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPTESTN	%VMM(4), %VMM(4), %k2
	VPTESTN	%VMM(6), %VMM(6), %k4
	KORTEST %k2, %k4
	jnz	L(loop_4x_done)

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%VMM(0), (VEC_SIZE * 0 + 0)(%rdi, %rsi)
	VMOVU	%VMM(1), (VEC_SIZE * 1 + 0)(%rdi, %rsi)
	VMOVU	%VMM(2), (VEC_SIZE * 2 + 0)(%rdi, %rsi)
	VMOVU	%VMM(3), (VEC_SIZE * 3 + 0)(%rdi, %rsi)

	subq	$(VEC_SIZE * -4), %rsi

	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(3)


	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPTESTN	%VMM(4), %VMM(4), %k2
	VPTESTN	%VMM(6), %VMM(6), %k4
	KORTEST %k2, %k4
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX
	addq	%rsi, %rdi
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x0_end)
	VMOVU	%VMM(0), (VEC_SIZE * 0 + 0)(%rdi)


	KMOV	%k2, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x1)
	VMOVU	%VMM(1), (VEC_SIZE * 1 + 0)(%rdi)

	VPTESTN	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x2)
	VMOVU	%VMM(2), (VEC_SIZE * 2 + 0)(%rdi)
	/* Place L(ret_vec_x4) here to save code size.  We get a
	   meaningfuly benefit doing this for stpcpy.  */
	KMOV	%k4, %VRDX
	bsf	%VRDX, %VRDX
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
L(return_end):
	ret

	.p2align 4,, 6
L(ret_vec_x0_end):
	bsf	%VRCX, %VRCX
	inc	%VRCX
	VMOVU	(-(VEC_SIZE))(%rsi, %rcx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), (-(VEC_SIZE))(%rdi, %rcx, CHAR_SIZE)
	ret

	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
	movq	%rsi, %rcx
	andq	$(VEC_SIZE * -1), %rcx

	VPCMPEQ	(%rcx), %VZERO, %k0
	KMOV	%k0, %VRCX
# ifdef USE_AS_WCSCPY
	andl	$(VEC_SIZE - 1), %PAGE_ALIGN_REG
	shrl	$2, %PAGE_ALIGN_REG
# endif
	shrxl	%PAGE_ALIGN_REG, %ecx, %ecx
# if 1
	/* Optimizing aggressively for space as this is very cold code.
	   This saves 2x cache lines.  */
	shll	%ecx
	jz	L(page_cross_continue)
	bsf	%VRCX, %VRCX
#  ifdef USE_AS_WCSCPY
	rep	movsd
#  else
	rep	movsb
#  endif


	ret

# else
	test	%VRCX, %VRCX
	jz	L(page_cross_continue)
	/* Dependency on rdi must already have been satisfied.  */
	bsf	%VRCX, %VRDX

	testw	%cx, %cx
	jz	L(page_cross_copy_16_31)

	testb	%cl, %cl
	jz	L(page_cross_copy_8_15)

	andl	$0x7, %ecx
	jz	L(page_cross_copy_4_7)

	test	%VRDX, %VRDX
	jz	L(page_cross_set_null_term)
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
L(page_cross_set_null_term):
	movb	$0, (%rdi, %rdx, CHAR_SIZE)
	ret


	.p2align 4,, 4
L(page_cross_copy_4_7):
	movl	(%rsi), %ecx
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %esi
	movl	%ecx, (%rdi)
	movl	%esi, -(4 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret
	.p2align 4,, 4
L(page_cross_copy_8_15):
	movq	(%rsi), %rcx
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %rsi
	movq	%rcx, (%rdi)
	movq	%rsi, -(8 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret


	.p2align 4,, 3
L(page_cross_copy_16_31):
	VMOVU	(%rsi), %xmm0
	VMOVU	-(16 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -(16 - CHAR_SIZE)%rdi, %rdx, CHAR_SIZE)
	ret

# endif



END(STRCPY)
#endif
