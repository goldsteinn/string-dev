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

# define PC_SHIFT_GPR	rdi
# define REG_WIDTH	VEC_SIZE
# define VPTESTN	vptestnmb
# define VPBROADCAST	vpbroadcastb
# define VPMINU	vpminub
# define VPCMP	vpcmpb
# define VPCMPEQ	vpcmpeqb
# define CHAR_SIZE	1

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






# if CHAR_PER_VEC == 64

#  define TAIL_RETURN_LBL	first_vec_x2
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 2)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x3
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 3)

# else	/* !(CHAR_PER_VEC == 64) */

#  define TAIL_RETURN_LBL	first_vec_x3
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 3)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x2
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 2)
# endif	/* !(CHAR_PER_VEC == 64) */


# define VMATCH	VEC(0)
# define VMATCH_LO	VEC_lo(0)

# define CHAR_PER_VEC	VEC_SIZE
# define PAGE_SIZE	4096


	.section SECTION(.text), "ax", @progbits
ENTRY_P2ALIGN(MEMCHR, 6)
	VPBROADCAST %esi, %VMATCH
	/* Check if we may cross page boundary with one vector load.  */
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

	VPCMPEQ	(%rdi), %VMATCH, %k0
	kmovV	%k0, %VRAX

	test	%VRAX, %VRAX
	jz	L(aligned_more)
L(first_vec_x0):
	bsf	%VRAX, %VRAX
	addq	%rdi, %rax
	ret

	.p2align 4,, 4
L(first_vec_x4):
	bsf	%VRAX, %VRAX
	leaq	(VEC_SIZE * 4)(%rdi, %rax), %rax
	ret

# if VEC_SIZE == 32
	.p2align 4,, 4
L(FALLTHROUGH_RETURN_LBL):
	bsf	%VRAX, %VRAX
	leaq	(FALLTHROUGH_RETURN_OFFSET)(%rdi, %rax), %rax
	ret
# endif

	.p2align 4,, 6
L(page_cross):
	/* eax has lower page-offset bits of rdi so xor will zero them
	   out.  */
	xorq	%rdi, %rax
	VPCMPEQ	(PAGE_SIZE - VEC_SIZE)(%rax), %VMATCH, %k0
	kmovV	%k0, %VRAX

	/* Shift out out-of-bounds matches.  */
	shrx	%VRDI, %VRAX, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x0)

	.p2align 4,, 10
L(aligned_more):
L(page_cross_continue):
	/* Align pointer.  */
	andq	$(VEC_SIZE * -1), %rdi

	VPCMPEQ	VEC_SIZE(%rdi), %VMATCH, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x3)

	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k0
	kmovV	%k0, %VRAX
	test	%VRAX, %VRAX
	jnz	L(first_vec_x4)

	subq	$-(VEC_SIZE * 1), %rdi
# if VEC_SIZE == 64
	/* Saves code size.  No evex512 processor has partial register
	   stalls.  If that change this can be replaced with `andq
	   $-(VEC_SIZE * 4), %rdi`.  */
	xorb	%dil, %dil
# else
	andq	$-(VEC_SIZE * 4), %rdi
# endif

# if USE_TERN_IN_LOOP
	/* copy VMATCH to low ymm/zmm so we can use vpcmpeq which is not
	   encodable with EVEX registers.  NB: this is VEC_SIZE == 32
	   only as there is no way to encode vpcmpeq with zmm0-15.  */
	vmovdqa64 %VMATCH, %VMATCH_LO
# endif

	.p2align 4
L(loop_4x_vec):
	/* Two versions of the loop.  One that does not require
	   vzeroupper by not using ymm/zmm0-15 and another does that
	   require vzeroupper because it uses ymm/zmm0-15.  The reason
	   why ymm/zmm0-15 is used at all is because there is no EVEX
	   encoding vpcmpeq and with vpcmpeq this loop can be performed
	   more efficiently.  The non-vzeroupper version is safe for
	   RTM while the vzeroupper version should be prefered if RTM
	   are not supported.   Which loop version we use is determined
	   by USE_TERN_IN_LOOP.  */

# if USE_TERN_IN_LOOP
	/* Since vptern can only take 3x vectors fastest to do 1 vec
	   seperately with EVEX vpcmp.  */
	VPCMPEQ	(VEC_SIZE * 4)(%rdi), %VMATCH, %k1
	/* Compare 3x with vpcmpeq and or them all together with vptern.
	 */

	VPCMPEQ	(VEC_SIZE * 5)(%rdi), %VMATCH_LO, %VEC_lo(2)
	subq	$(VEC_SIZE * -4), %rdi
	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VMATCH_LO, %VEC_lo(3)
	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VMATCH_LO, %VEC_lo(4)

	/* 254 is mask for oring VEC_lo(2), VEC_lo(3), VEC_lo(4) into
	   VEC_lo(4).  */
	vpternlogd $254, %VEC_lo(2), %VEC_lo(3), %VEC_lo(4)
	vpmovmskb %VEC_lo(4), %VRCX

	kmovd	%k1, %eax

	/* NB:  rax has match from first VEC and rcx has matches from
	   VEC 2-4.  If rax is non-zero we will return that match.  If
	   rax is zero adding won't disturb the bits in rcx.  */
	add	%rax, %rcx
# else
	/* Loop version that uses EVEX encoding.  */
	VPCMP	$4, (VEC_SIZE * 4)(%rdi), %VMATCH, %k1
	vpxorq	(VEC_SIZE * 5)(%rdi), %VMATCH, %VEC(2)
	vpxorq	(VEC_SIZE * 6)(%rdi), %VMATCH, %VEC(3)
	VPCMPEQ	(VEC_SIZE * 7)(%rdi), %VMATCH, %k3
	VPMINU	%VEC(2), %VEC(3), %VEC(3){%k1}{z}
	VPTESTN	%VEC(3), %VEC(3), %k2
	subq	$(VEC_SIZE * -4), %rdi
	kortestV %k2, %k3
# endif
	jz	L(loop_4x_vec)

# if USE_TERN_IN_LOOP
	test	%VRAX, %VRAX
# else
	kmovV	%k1, %VRAX
	inc	%VRAX
# endif
	jnz	L(last_vec_x0)


# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(2), %VRAX
# else
	VPTESTN	%VEC(2), %VEC(2), %k1
	kmovV	%k1, %VRAX
# endif
	test	%VRAX, %VRAX
	jnz	L(last_vec_x1)


# if USE_TERN_IN_LOOP
	vpmovmskb %VEC_lo(3), %VRAX
# else
	kmovV	%k2, %VRAX
# endif

	/* No longer need any of the lo vecs (ymm/zmm0-15) so vzeroupper
	   (only if used VEX encoded loop).  */
	COND_VZEROUPPER

# if CHAR_PER_VEC == 64
#  if USE_TERN_IN_LOOP
#   error "Unsupported"
#  endif


	/* If CHAR_PER_VEC == 64 we can't combine the last two VEC.  */
	test	%VRAX, %VRAX
	jnz	L(first_vec_x2)
	kmovV	%k3, %VRAX
L(FALLTHROUGH_RETURN_LBL):
# else
	/* CHAR_PER_VEC <= 32 so we can combine the results from the
	   last 2x VEC.  */
#  if !USE_TERN_IN_LOOP
	kmovV	%k3, %VRCX
#  endif
	salq	$CHAR_PER_VEC, %rcx
	addq	%rcx, %rax
# endif
	bsf	%rax, %rax
	leaq	(FALLTHROUGH_RETURN_OFFSET)(%rdi, %rax), %rax
	ret

	.p2align 4,, 8
L(TAIL_RETURN_LBL):
	bsf	%rax, %rax
	leaq	(TAIL_RETURN_OFFSET)(%rdi, %rax), %rax
	ret

	.p2align 4,, 8
L(last_vec_x1):
	COND_VZEROUPPER
L(first_vec_x1):
	bsf	%VRAX, %VRAX
	leaq	(VEC_SIZE * 1)(%rdi, %rax), %rax
	ret

	.p2align 4,, 8
L(last_vec_x0):
	COND_VZEROUPPER
	bsf	%VRAX, %VRAX
	addq	%rdi, %rax
	ret





END(MEMCHR)
#endif
