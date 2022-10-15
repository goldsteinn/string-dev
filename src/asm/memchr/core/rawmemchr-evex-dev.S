/* memchr/wmemchr optimized with 256-bit EVEX instructions.
   Copyright (C) 2021-2022 Free Software Foundation, Inc.
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
#define USE_IN_RTM
#ifndef MEMCHR
# define MEMCHR	slen
#endif
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif


#include "../../libc-asm-common.h"
#if ISA_SHOULD_BUILD (4)

# ifndef MEMCHR
#  define MEMCHR	__memchr_evex
# endif

# ifdef USE_AS_WMEMCHR
#  define PC_SHIFT_GPR	rcx
#  define REG_WIDTH	32
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPMINU	vpminud
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define CHAR_SIZE	4
# else
#  define PC_SHIFT_GPR	rdi
#  define REG_WIDTH	VEC_SIZE
#  define VPTESTN	vptestnmb
#  define VPBROADCAST	vpbroadcastb
#  define VPMINU	vpminub
#  define VPCMP	vpcmpb
#  define VPCMPEQ	vpcmpeqb
#  define CHAR_SIZE	1
# endif


# include "../../libc-defs/libc-reg-macros.h"

	/* In the 4x loop the RTM and non-RTM versions have data pointer
	   off by VEC_SIZE * 4 with RTM version being VEC_SIZE * 4
	   greater. This is represented by BASE_OFFSET. As well because
	   the RTM version uses vpcmp which stores a bit per element
	   compared where the non-RTM version uses vpcmpeq which stores
	   a bit per byte compared RET_SCALE of CHAR_SIZE is only
	   relevant for the RTM version.  */

# if defined USE_IN_RTM || VEC_SIZE == 64 || defined USE_AS_WMEMCHR
#  undef COND_VZEROUPPER
#  undef VZEROUPPER_RETURN
#  undef VZEROUPPER


#  define COND_VZEROUPPER
#  define VZEROUPPER_RETURN	ret
#  define VZEROUPPER

#  define USE_TERN_IN_LOOP	0
# else
#  define USE_TERN_IN_LOOP	1
#  undef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

# if USE_TERN_IN_LOOP
#  define TERN_CHAR_MULT	1

#  ifdef USE_AS_WMEMCHR
#   define TEST_END()	inc %VGPR(rcx)
#  else
#   define TEST_END()	add %rdx, %rcx
#  endif
# else
#  define TERN_CHAR_MULT	CHAR_SIZE
#  define TEST_END()	kortestV %k2, %k3
# endif


# define VMATCH	VEC(0)
# define VMATCH_LO	VEC_lo(0)

# ifndef SECTION
#  define SECTION(p)	p##.evex
# endif

# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# define PAGE_SIZE	4096

# if defined USE_AS_WMEMCHR || !USE_TERN_IN_LOOP
#  ifndef USE_AS_WMEMCHR
#   define GPR_X0_IS_RET	1
#  else
#   define GPR_X0_IS_RET	0
#  endif
#  define GPR_X0	rax
# else
#  define GPR_X0_IS_RET	0
#  define GPR_X0	rdx
# endif

# if CHAR_PER_VEC == 64
#  define LAST_VEC_OFFSET	(VEC_SIZE * 3)
# else
#  define LAST_VEC_OFFSET	(VEC_SIZE * 2)
# endif
# if CHAR_PER_VEC >= 32
#  define MASK_GPR(...)	VGPR(__VA_ARGS__)
# elif CHAR_PER_VEC == 16
#  define MASK_GPR(reg)	VGPR_SZ(reg, 16)
# else
#  define MASK_GPR(reg)	VGPR_SZ(reg, 8)
# endif




	.section SECTION(.text), "ax", @progbits
ENTRY_P2ALIGN(MEMCHR, 6)
	VPBROADCAST %esi, %VMATCH
	/* Check if we may cross page boundary with one vector load.  */
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

	VPCMPEQ	(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)
	/* This is a hard dependency on RSI to get RAX already so no
	   worries about false dep on destination.  */
	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)

	bsf	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret

	.p2align 4,, 6
L(last_vec_x1):
	COND_VZEROUPPER
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 1)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 6
L(last_vec_x2):
	COND_VZEROUPPER
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 6
L(last_vec_x3):
L(first_vec_x3):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(first_vec_x4):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 4)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(aligned_more):
	andq	$-VEC_SIZE, %rdi
L(page_cross_continue):
	VPCMPEQ	VEC_SIZE(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x4)


# if USE_TERN_IN_LOOP
	vmovdqa64 %VMATCH, %VMATCH_LO
# endif

	addq	$VEC_SIZE, %rdi
# if VEC_SIZE == 64
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif

	.p2align 4
L(loop_4x_vec):
# if USE_TERN_IN_LOOP
#  ifdef USE_AS_WMEMCHR
	VPCMP	$4, (VEC_SIZE * 0)(%rdi), %VMATCH, %k1
#  else
	VPCMPEQ	(VEC_SIZE * 0)(%rdi), %VMATCH, %k1
#  endif
	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VMATCH_LO, %VEC_lo(2)
	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH_LO, %VEC_lo(3)
	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH_LO, %VEC_lo(4)
#  ifdef USE_AS_WMEMCHR
	vpternlogd $1, %VEC_lo(2), %VEC_lo(3), %VEC_lo(4){%k1}{z}
	vpmovmskb %VEC_lo(4), %VGPR(rcx)
#  else
	/* 254 is mask for oring ymm2, ymm3, ymm4 into ymm4.  */
	vpternlogd $254, %VEC_lo(2), %VEC_lo(3), %VEC_lo(4)
	vpmovmskb %VEC_lo(4), %VGPR(rcx)
	kmovd	%k1, %edx
#  endif

# else
	VPCMP	$4, (VEC_SIZE * 4)(%rdi), %VMATCH, %k1
	vpxorq	(VEC_SIZE * 5)(%rdi), %VMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * 6)(%rdi), %VMATCH, %VEC(3)
	VPCMPEQ	(VEC_SIZE * 7)(%rdi), %VMATCH, %k3
	VPMINU	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	VPTESTN	%VEC(3), %VEC(3), %k2
# endif
	subq	$-(VEC_SIZE * 4), %rdi
	TEST_END ()
	jnz	L(loop_4x_vec)


	.p2align 4,, 4
L(loop_vec_ret):
# if defined USE_AS_WMEMCHR || !USE_TERN_IN_LOOP
	kmovV	%k1, %VGPR(rax)
	inc	%MASK_GPR(rax)
# else
	test	%VGPR(rax), %VGPR(rax)
# endif
	jnz	L(last_vec_x0)

# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(2), %VGPR(rdx)
# else
	VPTESTN	%VEC(2), %VEC(2), %k1
	kmovV	%k1, %VGPR(rdx)
# endif
	test	%VGPR(rdx), %VGPR(rdx)
	jnz	L(last_vec_x1)


# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(3), %VGPR(rdx)
# else
	kmovV	%k2, %VGPR(rdx)
# endif

	COND_VZEROUPPER

# if CHAR_PER_VEC == 64
	test	%VGPR(rdx), %VGPR(rdx)
	jnz	L(last_vec_x2)

#  if USE_TERN_IN_LOOP
#   error "Unsupported"
#  endif

	kmovV	%k3, %VGPR(rax)
# else

#  if !USE_TERN_IN_LOOP
	kmovV	%k3, %VGPR(rax)
#  endif
	salq	$CHAR_PER_VEC, %rax
	addq	%rdx, %rax
# endif
	bsf	%rdx, %rdx
	leaq	(LAST_VEC_OFFSET)(%rdi, %rax, TERN_CHAR_MULT), %rax
	ret


	.p2align 4,, 4
L(last_vec_x0):
	COND_VZEROUPPER
	bsf	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret



	.p2align 4,, 6
L(page_cross):
# ifdef USE_AS_WMEMCHR
	movl	%eax, %ecx
# endif

	xorq	%rdi, %rax
	VPCMPEQ	(PAGE_SIZE - VEC_SIZE)(%rax), %VMATCH, %k0
	kmovV	%k0, %VGPR(rax)

# ifdef USE_AS_WMEMCHR
	shrl	$2, %ecx
	andl	$(CHAR_PER_VEC - 1), %ecx
# endif

	shrx	%VGPR(PC_SHIFT_GPR), %VGPR(rax), %VGPR(rax)

	test	%VGPR(rax), %VGPR(rax)
	jz	L(page_cross_continue)
	tzcnt	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret

	.p2align 4,, 4

END(MEMCHR)
#endif
