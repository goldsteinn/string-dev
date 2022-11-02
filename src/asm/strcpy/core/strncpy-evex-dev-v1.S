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
#  include "../../libc-defs/libc-evex256-vecs.h"
# endif

# ifdef USE_AS_WCSCPY
#  define VMOVU_MASK	vmovdqu32
#  define VPCMPEQ	vpcmpeqd
#  define VPMIN	vpminud
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define CHAR_SIZE	4
#  define USE_WIDE_CHAR
# else
#  define VMOVU_MASK	vmovdqu8
#  define VPCMPEQ	vpcmpeqb
#  define VPMIN	vpminub
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define CHAR_SIZE	1
# endif
# define USE_EVEX_MASKED_STORE	0
# include "../../libc-defs/libc-reg-macros.h"

# define PAGE_SIZE	4096

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

# define VZERO	VMM(7)
# define VZERO_256	VMM_256(7)
# define VZERO_128	VMM_128(7)

# if VEC_SIZE == 64
#  define VZERO_HALF	VZERO_256
# else
#  define VZERO_HALF	VZERO_128
# endif


# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

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
# else
	decq	%rdx
	/* If the flag needs to become `jb` replace `dec` with `sub`.
	 */
	jl	L(zero_len)
# endif
	movl	%esi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

L(page_cross_continue):
	VMOVU	(%rsi), %VMM(0)
	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX

# ifndef USE_AS_STPCPY
	movq	%rdi, %rax
# endif


	cmpq	$(CHAR_PER_VEC), %rdx
	/* `jb` because length rdx is now length - 1.  */
# if USE_EVEX_MASKED_STORE
	jae	L(more_1x_vec)
	blsmsk	%VRCX, %VRSI
#  ifdef USE_AS_STPCPY
	tzcnt	%VRCX, %VRAX
	cmpl	%eax, %edx
	cmovb	%edx, %eax
	adcq	%rdi, %rax
#  endif

	KMOV	%VRSI, %k1
	VMOVU_MASK %VMM(0), %VMM(7){%k1}{z}
L(zfill_less_vec):
	incl	%edx
	mov	$-1, %VRCX
	bzhi	%VRDX, %VRCX, %VRCX
	KMOV	%VRCX, %k1
	VMOVU_MASK %VMM(7), (%rdi){%k1}
	ret

	.p2align 4,, 4
L(zero_len):
	cmpq	$-1, %rdx
	jne	L(best_effort_strncpy)
	movq	%rdi, %rax
	ret

	.p2align 4,, 8
L(more_1x_vec):
# else
	jb	L(less_1x_vec)
# endif




	/* This may overset but thats fine because we still need to zero
	   fill.  */
	VMOVU	%VMM(0), (%rdi)

	vpxorq	%VZERO_128, %VZERO_128, %VZERO_128
	test	%VRCX, %VRCX
	jnz	L(zfill)


	leaq	(VEC_SIZE * -1)(%rsi, %rdx, CHAR_SIZE), %rdx
	subq	%rsi, %rdi
	andq	$-(VEC_SIZE), %rsi

L(loop_last_4x_vec):
	addq	%rsi, %rdi
	subq	%rsi, %rdx
# if CHAR_SIZE == 4
	shrq	$2, %rdx
# endif

	VMOVA	(VEC_SIZE * 1)(%rsi), %VMM(1)
	VPTESTN	%VMM(1), %VMM(1), %k0
	KMOV	%k0, %VRCX

	cmpq	$(CHAR_PER_VEC * 2 - 1), %rdx
	ja	L(more_2x_vec)

L(last_2x_vec):
# if CHAR_PER_VEC == 64
	tzcntq	%rcx, %rcx
# endif

	cmpl	$(CHAR_PER_VEC), %edx
	jb	L(ret_vec_x1_len)

# if CHAR_PER_VEC == 64
	cmpb	$CHAR_PER_VEC, %cl
	jnz	L(ret_vec_x1_no_bsf)
# else
	test	%VRCX, %VRCX
	jnz	L(ret_vec_x1)
# endif



	VPCMPEQ	(VEC_SIZE * 2)(%rsi), %VZERO, %k0
	VMOVU	%VMM(1), (VEC_SIZE * 1)(%rdi)
	KMOV	%k0, %VRCX
# if CHAR_PER_VEC < 64
	shlq	$CHAR_PER_VEC, %rcx
# else
	tzcntq	%rcx, %rcx
	addl	$CHAR_PER_VEC, %ecx
# endif


L(ret_vec_x1_len):
# if CHAR_PER_VEC < 64
	tzcntq	%rcx, %rcx
# endif
	cmpl	%ecx, %edx
	jbe	L(ret_vec_x1_len_no_zfill)
	/* Fall through (expectation) is copy len < buffer len.  */
	VMOVU	%VZERO, ((VEC_SIZE)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
L(ret_vec_x1_len_no_zfill_mov):
	movl	%ecx, %edx
# ifdef USE_AS_STPCPY
	/* clear flags.  */
	xorl	%ecx, %ecx
# endif
L(ret_vec_x1_len_no_zfill):
	VMOVU	((VEC_SIZE)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
#  ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(VEC_SIZE * 1)(%rdi, %rdx, CHAR_SIZE), %rax
#  else
	leal	(VEC_SIZE)(%rdx), %eax
	adcq	%rdi, %rax
#  endif
# endif
	ret


	.p2align 4,, 6
L(ret_vec_x1):
	bsf	%VRCX, %VRCX
L(ret_vec_x1_no_bsf):
	VMOVU	%VZERO, ((VEC_SIZE)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
	subl	%ecx, %edx
	cmpl	$CHAR_PER_VEC, %edx
	jb	L(ret_vec_x1_len_no_zfill_mov)
	VMOVU	%VMM(1), (VEC_SIZE * 1)(%rdi)
	VMOVU	%VZERO, (VEC_SIZE * 1)(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 1)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

L(last_4x_vec):
# if CHAR_PER_VEC == 64
	movzbl	%dl, %edx
# else
	andl	$(CHAR_PER_VEC * 4 - 1), %edx
# endif
	VMOVA	(VEC_SIZE * 5)(%rsi), %VMM(1)
	VPTESTN	%VMM(1), %VMM(1), %k0
	KMOV	%k0, %VRCX
	subq	$-(VEC_SIZE * 4), %rsi
	subq	$-(VEC_SIZE * 4), %rdi
	cmpl	$(CHAR_PER_VEC * 2 - 1), %edx
	jbe	L(last_2x_vec)
	.p2align 4,, 12
L(more_2x_vec):
	VMOVU	%VMM(1), (VEC_SIZE * 1)(%rdi)
	test	%VRCX, %VRCX
	/* Must fill at least 2x VEC.  */
	jnz	L(zfill_vec1)

	VMOVA	(VEC_SIZE * 2)(%rsi), %VMM(2)
	VMOVU	%VMM(2), (VEC_SIZE * 2)(%rdi)
	VPTESTN	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	/* Must fill at least 1x VEC.  */
	jnz	L(zfill_vec2)

	VMOVA	(VEC_SIZE * 3)(%rsi), %VMM(3)
	VPTESTN	%VMM(3), %VMM(3), %k0
	KMOV	%k0, %VRCX

	/* Check if len is more 4x VEC. -1 because rdx is len - 1.  */
	cmpq	$(CHAR_PER_VEC * 4 - 1), %rdx
	ja	L(more_4x_vec)

	subl	$(CHAR_PER_VEC * 3), %edx
	jb	L(ret_vec_x3_len)

	test	%VRCX, %VRCX
	jnz	L(ret_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rsi), %VZERO, %k0
	VMOVU	%VMM(3), (VEC_SIZE * 3)(%rdi)
	KMOV	%k0, %VRCX
	tzcnt	%VRCX, %VRCX
	cmpl	%ecx, %edx
	jbe	L(ret_vec_x4_len_no_zfill)
	/* Fall through (expectation) is copy len < buffer len.  */
	VMOVU	%VZERO, ((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
	movl	%ecx, %edx
L(ret_vec_x4_len_no_zfill):
	VMOVU	((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE * 4)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
#  ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(VEC_SIZE * 4)(%rdi, %rdx, CHAR_SIZE), %rax
#  else
	leal	(VEC_SIZE * 4 + 0)(%rdx), %eax
	adcq	%rdi, %rax
#  endif
# endif
	ret


L(ret_vec_x3_len):
	addl	$(CHAR_PER_VEC * 1), %edx
	tzcnt	%VRCX, %VRCX
	cmpl	%ecx, %edx
	jbe	L(ret_vec_x3_len_no_zfill)
	/* Fall through (expectation) is copy len < buffer len.  */
	VMOVU	%VZERO, ((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
L(ret_vec_x3_len_no_zfill_mov):
	movl	%ecx, %edx
# ifdef USE_AS_STPCPY
	/* clear flags.  */
	xorl	%ecx, %ecx
# endif
	.p2align 4,, 4
L(ret_vec_x3_len_no_zfill):
	VMOVU	((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rsi, %rdx, CHAR_SIZE), %VMM(0)
	VMOVU	%VMM(0), ((VEC_SIZE * 3)-(VEC_SIZE - CHAR_SIZE))(%rdi, %rdx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
#  ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(VEC_SIZE * 3)(%rdi, %rdx, CHAR_SIZE), %rax
#  else
	leal	(VEC_SIZE * 3 + 0)(%rdx), %eax
	adcq	%rdi, %rax
#  endif
# endif
	ret


	.p2align 4,, 8
L(ret_vec_x3):
	bsf	%VRCX, %VRCX
	VMOVU	%VZERO, (VEC_SIZE * 4 +(-(VEC_SIZE - CHAR_SIZE)))(%rdi, %rdx, CHAR_SIZE)
	subl	%ecx, %edx
	jl	L(ret_vec_x3_len_no_zfill_mov)
	VMOVU	%VMM(3), (VEC_SIZE * 3)(%rdi)
	VMOVU	%VZERO, (VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE)
# ifdef USE_AS_STPCPY
	leaq	(VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE), %rax
# endif
	ret

	.p2align 4,, 8
L(more_4x_vec):
	VMOVU	%VMM(3), (VEC_SIZE * 3)(%rdi)
	test	%VRCX, %VRCX
	jnz	L(zfill_vec3)

	VMOVA	(VEC_SIZE * 4)(%rsi), %VMM(4)
	VMOVU	%VMM(4), (VEC_SIZE * 4)(%rdi)
	VPTESTN	%VMM(4), %VMM(4), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(zfill_vec4)


	/* Recheck length before aligning.  */
	cmpq	$(CHAR_PER_VEC * 8 - 1), %rdx
	jbe	L(last_4x_vec)

# if CHAR_SIZE != 1
	leaq	(%rsi, %rdx, CHAR_SIZE), %rdx
# else
	addq	%rsi, %rdx
# endif
	subq	%rsi, %rdi
	subq	$-(VEC_SIZE * 4), %rsi
	andq	$(VEC_SIZE * -4), %rsi



	VMOVA	(VEC_SIZE * 0 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(3)

	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPTESTN	%VMM(4), %VMM(4), %k2
	VPTESTN	%VMM(6), %VMM(6), %k4


	addq	$-(VEC_SIZE), %rsi
	KORTEST	%k2, %k4
	jnz	L(loop_4x_done)
	leaq	-(VEC_SIZE * 5 - CHAR_SIZE)(%rdx), %r9
	// movq    %rdx, %r9
	// andq    $(VEC_SIZE * -4), %r9

	.p2align 4,, 11
L(loop_4x_vec):
	VMOVU	%VMM(0), (VEC_SIZE * 1 + 0)(%rdi, %rsi)
	VMOVU	%VMM(1), (VEC_SIZE * 2 + 0)(%rdi, %rsi)
	VMOVU	%VMM(2), (VEC_SIZE * 3 + 0)(%rdi, %rsi)
	VMOVU	%VMM(3), (VEC_SIZE * 4 + 0)(%rdi, %rsi)

	subq	$(VEC_SIZE * -4), %rsi
	cmpq	%rsi, %r9
	jbe	L(loop_last_4x_vec)

	VMOVA	(VEC_SIZE * 1 + 0)(%rsi), %VMM(0)
	VMOVA	(VEC_SIZE * 2 + 0)(%rsi), %VMM(1)
	VMOVA	(VEC_SIZE * 3 + 0)(%rsi), %VMM(2)
	VMOVA	(VEC_SIZE * 4 + 0)(%rsi), %VMM(3)

	VPMIN	%VMM(0), %VMM(1), %VMM(4)
	VPMIN	%VMM(2), %VMM(3), %VMM(6)
	VPTESTN	%VMM(4), %VMM(4), %k2
	VPTESTN	%VMM(6), %VMM(6), %k4
	KORTEST	%k2, %k4
	jz	L(loop_4x_vec)

L(loop_4x_done):
	subq	%rsi, %rdx
# if CHAR_SIZE == 4
	shrq	$2, %rdx
# endif
	VMOVU	%VMM(0), (VEC_SIZE * 1 + 0)(%rdi, %rsi)
	addq	%rsi, %rdi
	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(zfill_vec1)

	VMOVU	%VMM(1), (VEC_SIZE * 2 + 0)(%rdi)
	KMOV	%k2, %VRCX
	test	%VRCX, %VRCX
	jnz	L(zfill_vec2)

	VMOVU	%VMM(2), (VEC_SIZE * 3 + 0)(%rdi)
	VPTESTN	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(zfill_vec3)

	VMOVU	%VMM(3), (VEC_SIZE * 4 + 0)(%rdi)
	KMOV	%k4, %VRCX
	// Zfill more....

	.p2align 4,, 4
L(zfill_vec4):
	subq	$(VEC_SIZE * -2), %rdi
	addq	$(CHAR_PER_VEC * -2), %rdx
L(zfill_vec2):
	subq	$(VEC_SIZE * -2), %rdi
	addq	$(CHAR_PER_VEC * -1), %rdx
L(zfill):
	bsf	%rcx, %rcx
	subq	%rcx, %rdx
# if CHAR_SIZE != 1
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
# else
	addq	%rcx, %rdi
# endif
# ifdef USE_AS_STPCPY
	movq	%rdi, %rax
# endif
L(zfill_from_page_cross):
	cmpq	$CHAR_PER_VEC, %rdx
	jb	L(zfill_less_vec)

L(zfill_more_1x_vec):
	VMOVU	%VZERO, (%rdi)
	VMOVU	%VZERO, (CHAR_SIZE - VEC_SIZE)(%rdi, %rdx, CHAR_SIZE)
	cmpq	$(CHAR_PER_VEC * 2 - 1), %rdx
	ja	L(zfill_more_2x_vec)
L(zfill_done0):
	ret

	.p2align 4,, 8
L(zfill_vec3):
	subq	$(VEC_SIZE * -2), %rdi
	addq	$(CHAR_PER_VEC * -2), %rdx
	.p2align 4,, 2
L(zfill_vec1):
	bsfq	%rcx, %rcx
	leaq	VEC_SIZE(%rdi, %rcx, CHAR_SIZE), %rdi
	subq	%rcx, %rdx
# ifdef USE_AS_STPCPY
	movq	%rdi, %rax
# endif
	VMOVU	%VZERO, (%rdi)
	VMOVU	%VZERO, (CHAR_SIZE - VEC_SIZE)(%rdi, %rdx, CHAR_SIZE)
	cmpq	$(CHAR_PER_VEC * 2), %rdx
	jb	L(zfill_done0)
L(zfill_more_2x_vec):
	VMOVU	%VZERO, (CHAR_SIZE - VEC_SIZE * 2)(%rdi, %rdx, CHAR_SIZE)
	VMOVU	%VZERO, (VEC_SIZE)(%rdi)
	subq	$(CHAR_PER_VEC * 4 - 1), %rdx
	jbe	L(zfill_done)

# if CHAR_SIZE != 1
	leaq	(%rdi, %rdx, CHAR_SIZE), %rdx
# else
	addq	%rdi, %rdx
# endif

	VMOVU	%VZERO, (VEC_SIZE * 2)(%rdi)
	VMOVU	%VZERO, (VEC_SIZE * 3)(%rdi)


	VMOVU	%VZERO, (VEC_SIZE * 0 + 0)(%rdx)
	VMOVU	%VZERO, (VEC_SIZE * 1 + 0)(%rdx)

	subq	$-(VEC_SIZE * 4), %rdi
	cmpq	%rdi, %rdx
	jbe	L(zfill_done)

	andq	$-(VEC_SIZE), %rdi
	.p2align 4,, 12
L(zfill_loop_4x_vec):
	VMOVA	%VZERO, (VEC_SIZE * 0)(%rdi)
	VMOVA	%VZERO, (VEC_SIZE * 1)(%rdi)
	VMOVA	%VZERO, (VEC_SIZE * 2)(%rdi)
	VMOVA	%VZERO, (VEC_SIZE * 3)(%rdi)
	subq	$-(VEC_SIZE * 4), %rdi
	cmpq	%rdi, %rdx
	ja	L(zfill_loop_4x_vec)
L(zfill_done):
	ret

# if !USE_EVEX_MASKED_STORE
	.p2align 4,, 8
L(copy_1x):
	VMOVU	%VMM(0), (%rdi)
	testl	%ecx, %ecx
	jz	L(ret_1x_1x)
	bsf	%VRCX, %VRCX
L(zfill_less_vec_no_bsf):
	subq	%rcx, %rdx
#  ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#  else
	addq	%rcx, %rdi
#  endif
#  ifdef USE_AS_STPCPY
	movq	%rdi, %rax
#  endif
L(zfill_less_vec):
	/* We are taking advantage of the fact that to be here we must
	   be writing null-term as (%rdi, %rcx) we have a byte of lee-
	   way for overwriting.  */
	cmpl	$((VEC_SIZE / 2) / CHAR_SIZE), %edx
	jb	L(zfill_less_half)

	VMOVU	%VZERO_HALF, (%rdi)
	VMOVU	%VZERO_HALF, -((VEC_SIZE / 2)- CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	ret
#  ifdef USE_AS_STPCPY
L(ret_1x_1x):
	leaq	CHAR_SIZE(%rdi, %rdx, CHAR_SIZE), %rax
	ret
#  endif


#  if VEC_SIZE == 64
	.p2align 4,, 4
L(copy_32_63):
	/* Overfill to avoid branches.  */
	VMOVU	-(32 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %VMM_256(1)
	VMOVU	%VMM_256(0), (%rdi)
	VMOVU	%VMM_256(1), -(32 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	cmpl	%ecx, %edx
	ja	L(zfill_less_vec_no_bsf)
#   ifndef USE_AS_STPCPY
L(ret_1x_1x):
#   else
#    ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#    else
	movl	%edx, %eax
	adcq	%rdi, %rax
#    endif
#   endif
	ret
#  endif

	.p2align 4,, 4
L(copy_16_31):
	/* Overfill to avoid branches.  */
	vmovdqu	-(16 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %xmm1
	VMOVU	%VMM_128(0), (%rdi)
	vmovdqu	%xmm1, -(16 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	cmpl	%ecx, %edx
#  if VEC_SIZE == 64
	jbe	L(ret_16_31)

	subl	%ecx, %edx
#   ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#   else
	addq	%rcx, %rdi
#   endif
#   ifdef USE_AS_STPCPY
	movq	%rdi, %rax
#   endif


L(zfill_less_half):
L(zfill_less_32):
	cmpl	$(16 / CHAR_SIZE), %edx
	jb	L(zfill_less_16)
	VMOVU	%VZERO_128, (%rdi)
	VMOVU	%VZERO_128, -(16 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
#   ifdef USE_AS_STPCPY
	ret
#   endif

L(ret_16_31):
#   ifdef USE_AS_STPCPY
#    ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#    else
	movl	%edx, %eax
	adcq	%rdi, %rax
#    endif
#   endif
	ret


#  else
	ja	L(zfill_less_vec_no_bsf)
#   ifndef USE_AS_STPCPY
L(ret_1x_1x):
#   else
#    ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#    else
	movl	%edx, %eax
	adcq	%rdi, %rax
#    endif
#   endif
	ret
#  endif


	.p2align 4,, 4
L(copy_8_15):
	/* Overfill to avoid branches.  */
	movq	-(8 - CHAR_SIZE)(%rsi, %rdx, CHAR_SIZE), %rsi
	vmovq	%VMM_128(0), (%rdi)
	movq	%rsi, -(8 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
	cmpl	%ecx, %edx
	jbe	L(ret_8_15)
	subl	%ecx, %edx
#  ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#  else
	addq	%rcx, %rdi
#  endif
#  ifdef USE_AS_STPCPY
	movq	%rdi, %rax
#  endif
	.p2align 4,, 8
#  if VEC_SIZE == 32
L(zfill_less_half):
#  endif
L(zfill_less_16):
	xorl	%ecx, %ecx
	cmpl	$(8 / CHAR_SIZE), %edx
	jb	L(zfill_less_8)
	movq	%rcx, (%rdi)
	movq	%rcx, -(8 - CHAR_SIZE)(%rdi, %rdx, CHAR_SIZE)
#  ifndef USE_AS_STPCPY
L(ret_8_15):
#  endif
	ret

	.p2align 4,, 8
L(less_1x_vec):
	je	L(copy_1x)

	tzcnt	%VRCX, %VRCX

#  if VEC_SIZE == 64
	cmpl	$(32 / CHAR_SIZE), %edx
	jae	L(copy_32_63)
#  endif

	cmpl	$(16 / CHAR_SIZE), %edx
	jae	L(copy_16_31)

	cmpl	$(8 / CHAR_SIZE), %edx
	jae	L(copy_8_15)
#  ifdef USE_AS_WCSCPY
	testl	%ecx, %ecx
	jz	L(zfill_less_8_set_ret)

	movl	(%rsi, %rdx, CHAR_SIZE), %esi
	vmovd	%VMM_128(0), (%rdi)
	movl	%esi, (%rdi, %rdx, CHAR_SIZE)
#   ifdef USE_AS_STPCPY
	cmpl	%ecx, %edx
L(ret_8_15):
	adcq	$0, %rdx
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#   endif
	ret
L(zfill_less_8_set_ret):
	xorl	%ecx, %ecx
#   ifdef USE_AS_STPCPY
	movq	%rdi, %rax
#   endif
L(zfill_less_8):
	movl	%ecx, (%rdi)
	movl	%ecx, (%rdi, %rdx, CHAR_SIZE)
	ret

#  else
	cmpl	$3, %edx
	jb	L(copy_0_3)
	/* Overfill to avoid branches.  */
	movl	-3(%rsi, %rdx), %esi
	vmovd	%VMM_128(0), (%rdi)
	movl	%esi, -3(%rdi, %rdx)
	cmpl	%ecx, %edx
	jbe	L(ret_4_7)
	subq	%rcx, %rdx
	addq	%rcx, %rdi
#   ifdef USE_AS_STPCPY
	movq	%rdi, %rax
#   endif
	xorl	%ecx, %ecx
	.p2align 4,, 8
L(zfill_less_8):
	cmpl	$3, %edx
	jb	L(zfill_less_3)
	movl	%ecx, (%rdi)
	movl	%ecx, -3(%rdi, %rdx)
#   ifdef USE_AS_STPCPY
	ret
#   endif

L(ret_4_7):
#   ifdef USE_AS_STPCPY
L(ret_8_15):
	movl	%edx, %eax
	adcq	%rdi, %rax
#   endif
	ret

	.p2align 4,, 4
L(zfill_less_3):
	testl	%edx, %edx
	jz	L(zfill_1)
	movw	%cx, (%rdi)
L(zfill_1):
	movb	%cl, (%rdi, %rdx)
	ret

	.p2align 4,, 8
L(copy_0_3):
	vmovd	%VMM_128(0), %r8d
	testl	%edx, %edx
	jz	L(copy_1)
	movw	%r8w, (%rdi)
	cmpl	%ecx, %edx
	ja	L(zfill_from_1)
	movzbl	(%rsi, %rdx), %r8d
#   ifdef USE_AS_STPCPY
	movl	%edx, %eax
	adcq	%rdi, %rax
	movb	%r8b, (%rdi, %rdx)
	ret
#   endif

L(copy_1):
#   ifdef USE_AS_STPCPY
	movl	%edx, %eax
	cmpl	%ecx, %edx
	adcq	%rdi, %rax
#   endif
#   ifdef USE_AS_WCSCPY
	vmovd	%VMM_128(0), (%rdi)
#   else
	movb	%r8b, (%rdi, %rdx)
#   endif
	ret
#  endif


#  ifndef USE_AS_WCSCPY
	.p2align 4,, 8
L(zfill_from_1):
#   ifdef USE_AS_STPCPY
	leaq	(%rdi, %rcx), %rax
#   endif
	movw	$0, -1(%rdi, %rdx)
	ret
#  endif

	.p2align 4,, 4
L(zero_len):
	cmpq	$-1, %rdx
	jne	L(best_effort_strncpy)
	movq	%rdi, %rax
	ret


# endif


	.p2align 4,, 4
	.p2align 6,, 8
L(page_cross):
	movq	%rsi, %rax
	andq	$(VEC_SIZE * -1), %rax
	VPCMPEQ	(%rax), %VZERO, %k0
	KMOV	%k0, %VRCX
# ifdef USE_AS_WCSCPY
	movl	%esi, %r8d
	shrl	$2, %r8d
	andl	$(CHAR_PER_VEC - 1), %r8d
	shrx	%VR8, %VRCX, %VRCX
# else
	shrx	%VRSI, %VRCX, %VRCX
# endif
	subl	%esi, %eax
	andl	$(VEC_SIZE - 1), %eax
# if CHAR_SIZE == 4
	shrl	$2, %eax
# endif
	cmpq	%rax, %rdx
	jb	L(page_cross_small)
	/* Optimizing aggressively for space as this is very cold code.
	   This saves 2x cache lines.  */
	test	%VRCX, %VRCX
	jz	L(page_cross_continue)
	bsf	%VRCX, %VRCX
L(movsb_and_zfill):
	incl	%ecx
	subq	%rcx, %rdx
# ifdef USE_AS_STPCPY
	leaq	-CHAR_SIZE(%rdi, %rcx, CHAR_SIZE), %rax
# else
	movq	%rdi, %rax
# endif
# ifdef USE_AS_WCSCPY
	rep	movsd
# else
	rep	movsb
# endif

# if USE_AS_WCSCPY
	movl	$0, (%rdi)
# else
	movb	$0, (%rdi)
# endif
	jmp	L(zfill_from_page_cross)

L(page_cross_small):
	tzcnt	%VRCX, %VRCX
	cmpl	%ecx, %edx
	ja	L(movsb_and_zfill)
	leal	1(%rdx), %ecx
# ifdef USE_AS_STPCPY
#  ifdef USE_AS_WCSCPY
	adcq	$0, %rdx
	leaq	(%rdi, %rdx, CHAR_SIZE), %rax
#  else
	movl	%edx, %eax
	adcq	%rdi, %rax
#  endif
# else
	movq	%rdi, %rax
# endif
# ifdef USE_AS_WCSCPY
	rep	movsd
# else
	rep	movsb
# endif
	ret


L(best_effort_strncpy):
# if 0
	leaq	1(%rdx), %rcx
	xorl	%eax, %eax
	movq	%rdi, %r8
	/* The length is >= 2^63. We very much so expect to segfault at
	   rep stos. If that doesn't happen then just strcpy to finish.
	 */
#  ifdef USE_AS_WCSCPY
	rep	stosl
	movq	%r8, %rdi
#   ifdef USE_AS_STPCPY
	jmp	__wcpcpy_evex
#   else
	jmp	__wcscpy_evex
#   endif
#  else
	rep	stosb
	movq	%r8, %rdi
#   ifdef USE_AS_STPCPY
	jmp	__stpcpy_evex
#   else
	jmp	__strcpy_evex
#   endif
#  endif
# endif

END(STRCPY)
#endif
