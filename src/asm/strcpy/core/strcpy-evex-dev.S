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
#  define PAGE_ALIGN_REG	edx
# else
#  define PAGE_ALIGN_REG	eax
# endif

# define VZERO	VEC(7)
# define VZERO_xmm	VEC_xmm(7)


# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)


	.section SECTION(.text), "ax", @progbits
ENTRY(STRCPY)
# ifdef USE_AS_STRCAT
	vpxorq	%VZERO_xmm, %VZERO_xmm, %VZERO_xmm
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %rdx
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %rdx
	VPCMPEQ	(%rdx), %VZERO, %k0
	kmovV	%k0, %VRCX
#  ifdef USE_AS_WCSCPY
	subl	%edx, %edi
	shrl	$2, %edi
#  endif
	shrx	%VRDI, %VRCX, %VRCX
#  ifdef USE_AS_WCSCPY
	movq	%rax, %rdi
#  endif
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%rdx), %VZERO, %k0
	kmovV	%k0, %VRCX
	leaq	(VEC_SIZE)(%rdx), %rdi
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%rdx), %VZERO, %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v1)

	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(0)
	VPMIN	(VEC_SIZE * 3)(%rdi), %VEC(0), %VEC(1)
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VRDX
	subq	$(VEC_SIZE * -2), %rdi
	test	%VRDX, %VRDX
	jz	L(loop_2x_vec)


	VPTESTN	%VEC(0), %VEC(0), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	mov	%VRDX, %VRCX

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsf	%VRCX, %VRCX
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

	VMOVU	(%rsi), %VEC(0)
# if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	movq	%rdi, %rax
# endif


# if 0
	VPTEST	%VEC(0), %VEC(0), %k0
	kmovV	%k0, %VRCX
#  ifdef USE_AS_WCSCPY
	subl	$((1 << CHAR_PER_VEC)- 1), %VRCX
#  else
	inc	%VRCX
#  endif
	jz	L(more_1x_vec)
	kmovV	%VRCX, %k1
	kxorV	%k0, %k1, %k1
#  ifdef USE_AS_WCSCPY
	vmovdqu32 %VEC(0), (%rdi){%k1}
#  else
	vmovdqu8 %VEC(0), (%rdi){%k1}
#  endif

#  ifdef USE_AS_STPCPY
	bsf	%VRCX, %VRCX
	leaq	(%rdi, %rcx, CHAR_SIZE), %rax
#  endif
	ret

# else
	VPTESTN	%VEC(0), %VEC(0), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jz	L(more_1x_vec)

	xorl	%edx, %edx
	bsf	%VRCX, %VRDX
#  ifdef USE_AS_STPCPY
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#  endif


#  if VEC_SIZE == 64
#   ifdef USE_AS_WCSCPY
	testb	%cl, %cl
#   else
	testl	%ecx, %ecx
#   endif
	jz	L(copy_32_63)
#  endif

#  ifdef USE_AS_WCSCPY
	testb	$0xf, %cl
#  else
	testw	%cx, %cx
#  endif
	jz	L(copy_16_31)


#  ifdef USE_AS_WCSCPY
	testb	$0x3, %cl
#  else
	testb	%cl, %cl
#  endif
	jz	L(copy_8_15)


#  ifdef USE_AS_WCSCPY
	vmovd	%VEC_xmm(0), (%rdi)
	movl	$0, (%END_REG)

	ret
#  else

	testb	$0x7, %cl
	jz	L(copy_4_7)


	test	%edx, %edx
	jz	L(set_null_term)

	/* NB: make this `vmovw` if support for AVX512-FP16 is added.
	 */
	vmovd	%VEC_xmm(0), %esi
	movw	%si, (%rdi)


	/* This only applies for stpcpy where we save a few bytes in
	   L(copy_...) because END_REG doesn't need an index.  */
	.p2align 4,, 1
L(set_null_term):
	movb	$0, (%END_REG)
	ret
#  endif

#  if VEC_SIZE == 64
	.p2align 4,, 6
L(copy_32_63):
	VMOVU	-(32 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %VEC_ymm(1)
	VMOVU	%VEC_ymm(0), (%rdi)
	VMOVU	%VEC_ymm(1), -(32 - CHAR_SIZE)(%END_REG)
	ret
#  endif

    
	.p2align 4,, 6
L(copy_16_31):
	/* Use xmm1 explicitly here as it won't require a `vzeroupper`
	   and will save code size.  */
	vmovdqu	-(16 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %xmm1
	VMOVU	%VEC_xmm(0), (%rdi)
	vmovdqu	%xmm1, -(16 - CHAR_SIZE)(%END_REG)
	ret

	.p2align 4,, 8
L(copy_8_15):
#  ifdef USE_AS_WCSCPY
	movl	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %ecx
#  else
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %rcx
#  endif
	vmovq	%VEC_xmm(0), (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%END_REG)
	ret
# endif
    

#  ifndef USE_AS_WCSCPY
	.p2align 4,, 12
L(copy_4_7):
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %ecx
	vmovd	%VEC_xmm(0), (%rdi)
	movl	%ecx, -(4 - CHAR_SIZE)(%END_REG)
	ret
#  endif



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
	VPTESTN	%VEC(1), %VEC(1), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jz	L(more_2x_vec)
	.p2align 4,, 1
L(ret_vec_x1):
	bsf	%VRCX, %VRCX
	VMOVU	(VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), (VEC_SIZE -(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	VEC_SIZE(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 7
	.p2align 6,, 14
L(more_2x_vec):
	VMOVA	(VEC_SIZE * 2)(%rsi), %VEC(2)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)

	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x2)

	VMOVA	(VEC_SIZE * 3)(%rsi), %VEC(3)
	VMOVU	%VEC(2), (VEC_SIZE * 2)(%rdi)

	VPTESTN	%VEC(3), %VEC(3), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jz	L(more_4x_vec)
	.p2align 4,, 1
L(ret_vec_x3):
	bsf	%VRCX, %VRCX
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 4
L(ret_vec_x2):
	bsf	%VRCX, %VRCX
	VMOVU	((VEC_SIZE * 2)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 2)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 2)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 6
L(ret_vec_x4):
	bsf	%VRCX, %VRCX
	VMOVU	((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 4)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 8
	.p2align 6,, 10
L(more_4x_vec):
	VMOVA	(VEC_SIZE * 4)(%rsi), %VEC(4)
	VMOVU	%VEC(3), (VEC_SIZE * 3)(%rdi)
	VPTESTN	%VEC(4), %VEC(4), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
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
	VPTESTN	%VEC(4), %VEC(4), %k2
	VPTESTN	%VEC(6), %VEC(6), %k4
	kortestV %k2, %k4
	jnz	L(loop_4x_done)

	.p2align 4,, 11
L(loop_4x_vec):

	VMOVU	%VEC(0), (VEC_SIZE * 0 + 0)(%rdi, %rsi)
	VMOVU	%VEC(1), (VEC_SIZE * 1 + 0)(%rdi, %rsi)
	VMOVU	%VEC(2), (VEC_SIZE * 2 + 0)(%rdi, %rsi)
	VMOVU	%VEC(3), (VEC_SIZE * 3 + 0)(%rdi, %rsi)

	subq	$(VEC_SIZE * -4), %rsi

	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VEC(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VEC(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VEC(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VEC(3)


	VPMIN	%VEC(0), %VEC(1), %VEC(4)
	VPMIN	%VEC(2), %VEC(3), %VEC(6)
	VPTESTN	%VEC(4), %VEC(4), %k2
	VPTESTN	%VEC(6), %VEC(6), %k4
	kortestV %k2, %k4
	jz	L(loop_4x_vec)

L(loop_4x_done):
	VPTESTN	%VEC(0), %VEC(0), %k0
	kmovV	%k0, %VRCX
	addq	%rsi, %rdi
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x0_end)
	VMOVU	%VEC(0), (VEC_SIZE * 0 + 0)(%rdi)


	kmovV	%k2, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x1)
	VMOVU	%VEC(1), (VEC_SIZE * 1 + 0)(%rdi)

	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x2)
	VMOVU	%VEC(2), (VEC_SIZE * 2 + 0)(%rdi)
	/* Place L(ret_vec_x4) here to save code size.  We get a
	   meaningfuly benefit doing this for stpcpy.  */
	kmovV	%k4, %VRDX
	bsf	%VRDX, %VRDX
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), ((VEC_SIZE * 3 + 0)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3 + 0)(%rdi, %rdx, CHAR_SIZE), %rax
# endif
L(return_end):
	ret

	.p2align 4,, 6
L(ret_vec_x0_end):
	bsf	%VRCX, %VRCX
# ifdef USE_AS_STPCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	inc	%VRCX
	VMOVU	(-(VEC_SIZE))(%rsi, %rcx, CHAR_SIZE), %VEC(0)
	VMOVU	%VEC(0), (-(VEC_SIZE))(%rdi, %rcx, CHAR_SIZE)
	ret

	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
# ifndef USE_AS_STRCAT
	vpxorq	%VZERO_xmm, %VZERO_xmm, %VZERO_xmm
# endif
	movq	%rsi, %rcx
	andq	$(VEC_SIZE * -1), %rcx

	VPCMPEQ	(%rcx), %VZERO, %k0
	kmovV	%k0, %VRCX
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
#  if !defined USE_AS_STPCPY && !defined USE_AS_STRCAT
	movq	%rdi, %rax
#  endif
	bsf	%VRCX, %VRCX
#  ifdef USE_AS_WCSCPY
	rep	movsd
#  else
	rep	movsb
#  endif

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
	test	%VRCX, %VRCX
	jz	L(page_cross_continue)
#  ifndef USE_AS_STRCAT
	xorl	%edx, %edx
#  endif
	/* Dependency on rdi must already have been satisfied.  */
	bsf	%VRCX, %VRDX
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

	test	%VRDX, %VRDX
	jz	L(page_cross_set_null_term)
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
L(page_cross_set_null_term):
	movb	$0, (%END_REG)
	ret


	.p2align 4,, 4
L(page_cross_copy_4_7):
	movl	(%rsi), %ecx
	movl	-(4 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %esi
	movl	%ecx, (%rdi)
	movl	%esi, -(4 - CHAR_SIZE)(%END_REG)
	ret
	.p2align 4,, 4
L(page_cross_copy_8_15):
	movq	(%rsi), %rcx
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %rsi
	movq	%rcx, (%rdi)
	movq	%rsi, -(8 - CHAR_SIZE)(%END_REG)
	ret


	.p2align 4,, 3
L(page_cross_copy_16_31):
	VMOVU	(%rsi), %xmm0
	VMOVU	-(16 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %xmm1
	VMOVU	%xmm0, (%rdi)
	VMOVU	%xmm1, -(16 - CHAR_SIZE)%END_REG)
	ret

# endif



END(STRCPY)
#endif
