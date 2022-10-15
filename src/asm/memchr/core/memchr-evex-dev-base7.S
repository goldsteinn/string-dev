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
#  define REG_WIDTH	32
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPMINU	vpminud
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define CHAR_SIZE	4
# else
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

# if defined USE_IN_RTM || VEC_SIZE == 64
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

#  ifdef USE_AS_WMEMCHR
#   define TEST_END()	inc %VGPR(rcx)
#  else
#   define TEST_END()	add %rdx, %rcx
#  endif
# else
#  define TEST_END()	kortestV %k2, %k3
# endif

	/* In the return from 4x loop memchr and rawmemchr versions have
	   data pointers off by VEC_SIZE * 4 with memchr version being
	   VEC_SIZE * 4 greater.  */
# ifdef USE_AS_RAWMEMCHR
#  define RET_OFFSET	(BASE_OFFSET - (VEC_SIZE * 4))
#  define RAW_PTR_REG	rcx
#  define ALGN_PTR_REG	rdi
# else
#  define RET_OFFSET	BASE_OFFSET
#  define RAW_PTR_REG	rdi
#  define ALGN_PTR_REG	rcx
# endif

# define VMATCH	VEC(0)
# define VMATCH_LO	VEC_lo(0)

# ifndef SECTION
#  define SECTION(p)	p##.evex
# endif

# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# define PAGE_SIZE	4096

	.section SECTION(.text), "ax", @progbits
ENTRY_P2ALIGN(MEMCHR, 6)
# ifndef USE_AS_RAWMEMCHR
	/* Check for zero length.  */
	test	%RDX_LP, %RDX_LP
	jz	L(zero_0)

#  ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%edx, %edx
#  endif
# endif
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
	tzcnt	%eax, %esi
	cmpq	%rsi, %rdx
	jbe	L(zero_0)
	test	%eax, %eax
	jz	L(aligned_more)
	leaq	(%rdi, %rsi), %rax
	ret
L(zero_0):
	xorl	%eax, %eax
	ret

L(aligned_more):
	leaq	-(VEC_SIZE + 1)(%rdx, %rdi), %rax
	andq	$(VEC_SIZE * -1), %rdi
	subq	%rdi, %rax

	VPCMPEQ	VEC_SIZE(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)


	/* We cannot fold the above `sub %rdi, %rax` with the `cmp
	   $(CHAR_PER_VEC * 2), %rax` because its possible for a very
	   large length to overflow and cause the subtract to carry
	   despite length being above CHAR_PER_VEC * 2.  */
	cmpq	$(CHAR_PER_VEC * 2 - 1), %rax
	ja	L(more_2x_vec)
L(last_2x_vec):

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x1_check)

	/* Check the end of data.  */
	subl	$(CHAR_PER_VEC * 1 - 1), %eax
	jbe	L(zero_0)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	tzcnt	%VGPR(rcx), %VGPR(rcx)
	cmp	%cl, %al
	jbe	L(zero_0)
	leaq	(VEC_SIZE * 2)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 8
L(first_vec_x1_check):
	bsf	%VGPR(rcx), %VGPR(rcx)
	cmpb	%cl, %al
	jbe	L(zero_0)
	leaq	(VEC_SIZE * 1)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 6
L(last_4x_vec):
	decl	%eax
	subq	$-(VEC_SIZE * 4), %rdi
L(last_4x_vec_begin):
	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	cmpb	$(CHAR_PER_VEC * 2 - 1), %al
	jbe	L(last_2x_vec)
	.p2align 4,, 6
L(more_2x_vec):

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	subq	$(CHAR_PER_VEC * 4 - 1), %rax
	ja	L(more_4x_vec)

	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x3_check)

	addl	$(CHAR_PER_VEC * 1), %eax
	jle	L(zero_2)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	tzcnt	%VGPR(rcx), %VGPR(rcx)
	cmp	%cl, %al
	ja	L(first_vec_x4_ret)
L(zero_2):
	xorl	%eax, %eax
	ret

	.p2align 4,, 4
L(first_vec_x4):
	bsf	%VGPR(rcx), %VGPR(rcx)
L(first_vec_x4_ret):
	leaq	(VEC_SIZE * 4)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 6
L(first_vec_x3_check):
	subb	$-(CHAR_PER_VEC * 2), %al
	bsf	%VGPR(rcx), %VGPR(rcx)
	cmpb	%cl, %al
	ja	L(first_vec_x3_ret)
	xorl	%eax, %eax
	ret

	.p2align 4,, 6
L(first_vec_x1):
	bsf	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 1)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 8
L(first_vec_x2):
	bsf	%VGPR(rcx), %VGPR(rcx)
	leaq	(VEC_SIZE * 2)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 8
L(first_vec_x3):
	bsf	%VGPR(rcx), %VGPR(rcx)
L(first_vec_x3_ret):
	leaq	(VEC_SIZE * 3)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 8
L(loop_last_4x_vec):
	COND_VZEROUPPER
	subq	$-(VEC_SIZE * 3), %rdi
	subl	$-(CHAR_PER_VEC * 4 - 1), %eax
	jmp	L(last_4x_vec_begin)

	.p2align 4,, 12
L(more_4x_vec):
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x4)

	cmpq	$(VEC_SIZE * 4), %rax
	jbe	L(last_4x_vec)


	addq	$VEC_SIZE, %rdi
	addq	%rdi, %rax
	andq	$-(VEC_SIZE * 4), %rdi
	subq	%rdi, %rax

# if USE_TERN_IN_LOOP
	vmovdqa64 %VMATCH, %VMATCH_LO
# endif
	.p2align 4
L(loop_4x_vec):
	subq	$(CHAR_PER_VEC * 4), %rax
	jbe	L(loop_last_4x_vec)


# if USE_TERN_IN_LOOP
#  ifdef USE_AS_WMEMCHR
	VPCMP	$4, (VEC_SIZE * 4)(%rdi), %VMATCH, %k1
#  else
	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k1
#  endif
	VPCMPEQ	(VEC_SIZE * 5)(%rdi), %VMATCH_LO, %VEC_lo(2)
	VPCMPEQ	(VEC_SIZE * 6)(%rdi), %VMATCH_LO, %VEC_lo(3)
	VPCMPEQ	(VEC_SIZE * 7)(%rdi), %VMATCH_LO, %VEC_lo(4)
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
	kmovV	%k2, %VGPR(rcx)
# endif
	subq	$-(VEC_SIZE * 4), %rdi

	TEST_END ()
	jz	L(loop_4x_vec)

L(loop_vec_ret):

# if defined USE_AS_WMEMCHR || !USE_TERN_IN_LOOP
	kmovV	%k1, %VGPR(rdx)
	inc	%VGPR(rdx)
# else
	test	%VGPR(rdx), %VGPR(rdx)
# endif
	jnz	L(last_vec_x1)

# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(2), %VGPR(rdx)
# else
	VPTESTN	%VEC(2), %VEC(2), %k1
	kmovV	%k1, %VGPR(rdx)
# endif
	test	%VGPR(rdx), %VGPR(rdx)
	jnz	L(last_vec_x2)


# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(3), %VGPR(rdx)
# else
	kmovV	%k2, %VGPR(rdx)
# endif

	COND_VZEROUPPER

# if CHAR_PER_VEC == 64
	test	%VGPR(rdx), %VGPR(rdx)
	jnz	L(last_vec_x3)

#  if USE_TERN_IN_LOOP
#   error "Unsupported"
#  endif

	kmovV	%k3, %VGPR(rcx)
# else

#  if !USE_TERN_IN_LOOP
	kmovV	%k3, %VGPR(rcx)
#  endif
	salq	$CHAR_PER_VEC, %rcx
	addq	%rdx, %rcx
# endif
	bsf	%rcx, %rcx
	leaq	(VEC_SIZE * 2)(%rdi, %rcx), %rax
	ret

L(last_vec_x1):
	bsf	%VGPR(rdx), %VGPR(rdx)
	leaq	(VEC_SIZE * 0)(%rdi, %rdx), %rax
	VZEROUPPER_RETURN


# if CHAR_PER_VEC == 64
L(last_vec_x3):
	addq	$VEC_SIZE, %rdi
# endif
L(last_vec_x2):
	bsf	%VGPR(rdx), %VGPR(rdx)
	leaq	(VEC_SIZE * 1)(%rdi, %rdx), %rax
	VZEROUPPER_RETURN


L(zero_end_0):
	xorl	%eax, %eax
	VZEROUPPER_RETURN
L(page_cross):



	// L(page_cross):
	ud2
	.p2align 4,, 4

END(MEMCHR)
#endif
