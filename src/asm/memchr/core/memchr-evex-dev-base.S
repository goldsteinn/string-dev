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
# include "../../libc-defs/libc-evex512-vecs.h"
#endif

#include "../../libc-asm-common.h"
#if ISA_SHOULD_BUILD (4)

# ifndef MEMCHR
#  define MEMCHR	__memchr_evex
# endif

# ifdef USE_AS_WMEMCHR
#  define VPTESTN	vptestnmd
#  define VPBROADCAST	vpbroadcastd
#  define VPMINU	vpminud
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define CHAR_SIZE	4
# else
#  define VPTESTN	vptestnmb
#  define VPBROADCAST	vpbroadcastb
#  define VPMINU	vpminub
#  define VPCMP	vpcmpb
#  define VPCMPEQ	vpcmpeqb
#  define CHAR_SIZE	1
# endif
# undef USE_AS_RAWMEMCHR
	/* In the 4x loop the RTM and non-RTM versions have data pointer
	   off by VEC_SIZE * 4 with RTM version being VEC_SIZE * 4
	   greater. This is represented by BASE_OFFSET. As well because
	   the RTM version uses vpcmp which stores a bit per element
	   compared where the non-RTM version uses vpcmpeq which stores
	   a bit per byte compared RET_SCALE of CHAR_SIZE is only
	   relevant for the RTM version.  */
# undef VZEROUPPER
# ifdef USE_IN_RTM
#  define VZEROUPPER
#  define BASE_OFFSET	(VEC_SIZE * 4)
#  define RET_SCALE	CHAR_SIZE
# else
#  define VZEROUPPER	vzeroupper
#  define BASE_OFFSET	0
#  define RET_SCALE	1
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

# define XMMZERO	VEC_xmm(1)
# define VZERO	VEC(1)

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
	jz	L(zero)

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
	ja	L(cross_page_boundary)

	VPCMPEQ	(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)

# ifndef USE_AS_RAWMEMCHR
	/* If length < CHAR_PER_VEC handle special.  */
	cmpq	$CHAR_PER_VEC, %rdx
	jbe	L(first_vec_x0_check)
# endif

	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
L(first_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WMEMCHR
	/* NB: Multiply bytes by CHAR_SIZE to get the wchar_t count.  */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret

# ifndef USE_AS_RAWMEMCHR
L(zero):
	xorl	%eax, %eax
	ret

	.p2align 4
L(first_vec_x0_check):
	/* Check if first match was before length. NB: tzcnt has false
	   data- dependency on destination. eax already had a data-
	   dependency on esi so this should have no affect here.  */
	tzcnt	%VGPR(rax), %VGPR(rax)
#  ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rsi, CHAR_SIZE), %rdi
#  else
	addq	%rsi, %rdi
#  endif
	xorl	%eax, %eax
	cmpl	%esi, %edx
	cmovg	%rdi, %rax
	ret
# endif

L(aligned_more):
# ifndef USE_AS_RAWMEMCHR
	addq	%rdi, %rdx
	movq	%rdx, %rcx
# endif
	orq	$(VEC_SIZE - 1), %rdi
	incq	%rdi
# ifndef USE_AS_RAWMEMCHR
	subq	%rdi, %rdx
# endif
L(last_4x_vec_or_less):

	VPCMPEQ	(VEC_SIZE * 0)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)

	cmpq	$(CHAR_PER_VEC * 2), %rdx
	ja	L(more_2x_vec)
L(last_2x_vec_or_less):
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(last_vec_x0_check)

	/* Check the end of data.  */
	subl	$CHAR_PER_VEC, %edx
	jbe	L(zero)

	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)
L(last_vec_x0_check):
	tzcnt	%VGPR(rax), %VGPR(rax)
	subq	%rdx, %rax
	jae	L(zero)
	addq	%rcx, %rax
	ret
# if (defined USE_IN_RTM) || VEC_SIZE == 64
L(last_vec_x1):
# endif
L(first_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4,, 10
L(last_4x_vec_or_less_3):
	COND_VZEROUPPER
L(last_4x_vec_or_less_2):
	subl	$(CHAR_PER_VEC * -4), %esi
	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k0
	subq	$(VEC_SIZE * -4), %rdi
	Vkmov	%k0, %VGPR(rax)


	cmpl	$(CHAR_PER_VEC * 2), %esi
	jbe	L(last_2x_vec_or_less)

	.p2align 4,, 4
L(more_2x_vec):
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x0_2)

	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)
	cmpq	$(CHAR_PER_VEC * 4), %rdx
	ja	L(more_4x_vec)


	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2_check)

	subq	$(CHAR_PER_VEC * 3), %rdx
	jbe	L(zero)
	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	subq	%rdx, %rax
	jae	L(zero_2)
	addq	%rcx, %rax
	ret
# if 1

L(zero_2):
	xorl	%eax, %eax
	ret
#  if (defined USE_IN_RTM) || VEC_SIZE == 64
L(last_vec_x0):
#  endif
L(first_vec_x0_2):
	bsf	%VGPR(rax), %VGPR(rax)
#  ifdef USE_AS_WMEMCHR
	/* NB: Multiply bytes by CHAR_SIZE to get the wchar_t count.  */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
#  else
	addq	%rdi, %rax
#  endif
	ret
# endif


	.p2align 4,, 10
L(first_vec_x2_check):
	bsf	%VGPR(rax), %VGPR(rax)
	subl	$(CHAR_PER_VEC * -2), %edx
	cmpl	%eax, %edx
	jbe	L(zero_2)
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

L(first_vec_x3):
	addq	$VEC_SIZE, %rdi
# if (defined USE_IN_RTM) || VEC_SIZE == 64
L(last_vec_x2):
# endif
L(first_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 4,, 10
L(more_4x_vec):
	test	%VGPR(rax), %VGPR(rax)
	jnz	L(first_vec_x2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH, %k0
	Vkmov	%k0, %VGPR(rax)
	jnz	L(first_vec_x3)

	subq	$(CHAR_PER_VEC * 8), %rdx
	jbe	L(last_4x_vec_or_less_2)


# if VEC_SIZE == 64
	/* evex512 machines having merging uop and no partial register
	   stalls.  */
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif

# ifdef USE_AS_MEMCHR
	movq	%rcx, %rdx
	subq	%rdi, %rdx
# endif

# if !(defined USE_IN_RTM || VEC_SIZE == 64)
	/* copy ymmmatch to ymm0 so we can use vpcmpeq which is not
	   encodable with EVEX registers (ymm16-ymm31).  */
	vmovdqa64 %VMATCH, %VMATCH_LO
# endif
	.p2align 4
L(loop_4x_vec):
	subq	$(CHAR_PER_VEC * 4), %rdx
	jbe	L(last_4x_vec_or_less_3)

# if defined USE_IN_RTM || VEC_SIZE == 64
	/* It would be possible to save some instructions using 4x VPCMP
	   but bottleneck on port 5 makes it not woth it.  */
	VPCMP	$4, (VEC_SIZE * 4)(%rdi), %VMATCH, %k1
	/* xor will set bytes match esi to zero.  */
	vpxorq	(VEC_SIZE * 5)(%rdi), %VMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * 6)(%rdi), %VMATCH, %VEC(3)
	VPCMP	$0, (VEC_SIZE * 7)(%rdi), %VMATCH, %k3
	/* Reduce VEC2 / VEC3 with min and VEC1 with zero mask.  */
	VPMINU	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	VPTESTN	%VEC(3), %VEC(3), %k2
# else
#  ifdef USE_AS_WMEMCHR
	/* vptern can only accept masks for epi32/epi64 so can only save
	   instruction using not equals mask on vptern with wmemchr.
	 */
	VPCMP	$4, (%rdi), %VMATCH, %k1
#  else
	VPCMPEQ	(%rdi), %VMATCH, %k1
#  endif
	VPCMPEQ	VEC_SIZE(%rdi), %VMATCH_LO, %VEC_lo(2)
	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH_LO, %VEC_lo(3)
	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH_LO, %VEC_lo(4)

#  ifdef USE_AS_WMEMCHR
	/* This takes the not of or between ymm2, ymm3, ymm4 as well as
	   combines result from VEC0 with zero mask.  */
	vpternlogd $1, %VEC_lo(2), %VEC_lo(3), %VEC_lo(4){%k1}{z}
	vpmovmskb %VEC_lo(4), %VGPR(rcx)
#  else
	/* 254 is mask for oring VEC_lo(2), VEC_lo(3), VEC_lo(4) into
	   VEC_lo(4).  */
	vpternlogd $254, %VEC_lo(2), %VEC_lo(3), %VEC_lo(4)
	vpmovmskb %VEC_lo(4), %VGPR(rcx)
	kmovd	%k1, %VGPR(rax)
#  endif
# endif

	subq	$-(VEC_SIZE * 4), %rdi
# if defined USE_IN_RTM || VEC_SIZE == 64
	kortestd %k2, %k3
# else
#  ifdef USE_AS_WMEMCHR
	/* ecx contains not of matches. All 1s means no matches. incl
	   will overflow and set zeroflag if that is the case.  */
	inc	%VGPR(rcx)
#  else
	/* If either VEC1 (eax) or VEC2-VEC4 (ecx) are not zero. Adding
	   to ecx is not an issue because if eax is non-zero it will be
	   used for returning the match. If it is zero the add does
	   nothing.  */
	addq	%rax, %rcx
#  endif
# endif
	jz	L(loop_4x_vec)


# if defined USE_IN_RTM || defined USE_AS_WMEMCHR || VEC_SIZE == 64
	/* k1 has not of matches with VEC1.  */
	Vkmov	%k1, %VGPR(rax)
#  ifdef USE_AS_WMEMCHR
	subl	$((1 << CHAR_PER_VEC)- 1), %VGPR(rax)
#  else
	inc	%VGPR(rax)
#  endif
# else
	/* eax already has matches for VEC1.  */
	testl	%VGPR(rax), %VGPR(rax)
# endif
	jnz	L(last_vec_x0)

# if defined USE_IN_RTM || VEC_SIZE == 64
	VPTESTN	%VEC(2), %VEC(2), %k0
	Vkmov	%k0, %VGPR(rax)
# else
	vpmovmskb %VEC_lo(2), %eax
# endif
	testl	%eax, %eax
	jnz	L(last_vec_x1)

# if defined USE_IN_RTM || VEC_SIZE == 64
	VPTESTN	%VEC(3), %VEC(3), %k0
	Vkmov	%k0, %VGPR(rax)
	testl	%eax, %eax
	jnz	L(last_vec_x2)

	Vkmov	%k3, %VGPR(rax)
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	(VEC_SIZE * 3 + RET_OFFSET)(%rdi, %rax, CHAR_SIZE), %rax
	ret
# else
	vpmovmskb %VEC_lo(3), %eax
	salq	$VEC_SIZE, %rcx
	orq	%rcx, %rax
	bsfq	%rax, %rax
	leaq	(VEC_SIZE * 2 + RET_OFFSET)(%rdi, %rax), %rax
L(return_vzeroupper):
	ZERO_UPPER_VEC_REGISTERS_RETURN


L(last_vec_x0):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	-(VEC_SIZE * 4)(%rdi, %rax, CHAR_SIZE), %rax
	VZEROUPPER_RETURN

L(last_vec_x1):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	-(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	VZEROUPPER_RETURN

L(last_vec_x2):
	bsf	%VGPR(rax), %VGPR(rax)
	leaq	-(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	VZEROUPPER_RETURN
# endif

L(cross_page_boundary):
	ud2

END(MEMCHR)
#endif
