/* strchr/strchrnul optimized with 256-bit EVEX instructions.
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
#include "../../libc-asm-common.h"
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex512-vecs.h"
#endif
#if ISA_SHOULD_BUILD (4)


# ifndef STRCHR
#  define STRCHR	__strchr_evex
# endif

# define VMOVU	vmovdqu64
# define VMOVA	vmovdqa64

# ifdef USE_AS_WCSCHR
#  define REG_WIDTH	32
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMINU	vpminud
#  define CHAR_REG	esi
#  define SHIFT_REG	ecx
#  define CHAR_SIZE	4
# else
#  define REG_WIDTH	VEC_SIZE
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
#  define VPCMPEQ	vpcmpeqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMINU	vpminub
#  define CHAR_REG	sil
#  define SHIFT_REG	edi
#  define CHAR_SIZE	1
# endif

# if VEC_SIZE == 64
#  define MASK_GPR	rcx
#  define LOOP_REG	rax

#  define COND_MASK(k_reg)	{%k_reg}
# else
#  define MASK_GPR	rax
#  define LOOP_REG	rdi

#  define COND_MASK(k_reg)
# endif

# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)


# if CHAR_PER_VEC == 64
#  define LAST_VEC_OFFSET	(VEC_SIZE * 3)
#  define TESTZ(reg)	incq %VGPR_SZ(reg, 64)
# else

#  if CHAR_PER_VEC == 32
#   define TESTZ(reg)	incl %VGPR_SZ(reg, 32)
#  elif CHAR_PER_VEC == 16
#   define TESTZ(reg)	incw %VGPR_SZ(reg, 16)
#  else
#   define TESTZ(reg)	incb %VGPR_SZ(reg, 8)
#  endif

#  define LAST_VEC_OFFSET	(VEC_SIZE * 2)
# endif

# define VMATCH	VEC(0)

# include "../../libc-defs/libc-reg-macros.h"

# define PAGE_SIZE	4096


	.section .text.evex, "ax", @progbits
ENTRY_P2ALIGN(STRCHR, 6)
	/* Broadcast CHAR to VEC_0.  */
	VPBROADCAST %esi, %VMATCH
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	/* Check if we cross page boundary with one vector load.
	   Otherwise it is safe to use an unaligned load.  */
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page_boundary)

	/* Check the first VEC_SIZE bytes. Search for both CHAR and the
	   null bytes.  */
	VMOVU	(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rax)
	test	%VGPR(rax), %VGPR(rax)
	jz	L(aligned_more)
	bsf	%VGPR(rax), %VGPR(rax)
# ifndef USE_AS_STRCHRNUL
	/* Found CHAR or the null byte.  */
	cmp	(%rdi, %rax, CHAR_SIZE), %CHAR_REG
	/* NB: Use a branch instead of cmovcc here. The expectation is
	   that with strchr the user will branch based on input being
	   null. Since this branch will be 100% predictive of the user
	   branch a branch miss here should save what otherwise would
	   be branch miss in the user code. Otherwise using a branch 1)
	   saves code size and 2) is faster in highly predictable
	   environments.  */
	jne	L(zero)
# endif
# ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
	ret

# ifndef USE_AS_STRCHRNUL
L(zero):
	xorl	%eax, %eax
	ret
# endif





	.p2align 4,, 2
L(first_vec_x3):
	subq	$-(VEC_SIZE * 2), %rdi
# if VEC_SIZE == 32
L(last_vec_x2):
# endif
L(first_vec_x1):
	/* Use bsf here to save 1-byte keeping keeping the block in 1x
	   fetch block. eax guranteed non-zero.  */
	bsf	%VGPR(rcx), %VGPR(rcx)
# ifndef USE_AS_STRCHRNUL
	/* Found CHAR or the null byte.  */
	cmp	(VEC_SIZE)(%rdi, %rcx, CHAR_SIZE), %CHAR_REG
	jne	L(zero)

# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE)(%rdi, %rcx, CHAR_SIZE), %rax
	ret

	.p2align 4,, 2
L(first_vec_x4):
	subq	$-(VEC_SIZE * 2), %rdi
L(first_vec_x2):
# ifndef USE_AS_STRCHRNUL
	/* Check to see if first match was CHAR (k0) or null (k1).  */
	kmovV	%k0, %VGPR(rax)
	tzcnt	%VGPR(rax), %VGPR(rax)
	kmovV	%k1, %VGPR(rcx)
	/* bzhil will not be 0 if first match was null.  */
	bzhi	%VGPR(rax), %VGPR(rcx), %VGPR(rcx)
	jne	L(zero)
# else
	/* Combine CHAR and null matches.  */
	korV	%k0, %k1, %k0
	kmovV	%k0, %VGPR(rax)
	bsf	%VGPR(rax), %VGPR(rax)
# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret


	.p2align 4
L(aligned_more):
L(cross_page_continue):
	/* Align data to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi

	/* Check the next 4 * VEC_SIZE. Only one VEC_SIZE at a time
	   since data is only aligned to VEC_SIZE. Use two alternating
	   methods for checking VEC to balance latency and port
	   contention.  */

// abf-off
    /* Method(1) with 8c latency:
	   For VEC_SIZE == 32:
	   p0 * 1.83, p1 * 0.83, p5 * 1.33
	   For VEC_SIZE == 64:
	   p0 * 2.50, p1 * 0.00, p5 * 1.50  */
// abf-on
	VMOVA	(VEC_SIZE)(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x1)

// abf-off
    /* Method(2) with 6c latency:
	   For VEC_SIZE == 32:
	   p0 * 1.00, p1 * 0.00, p5 * 2.00
	   For VEC_SIZE == 64:
	   p0 * 1.00, p1 * 0.00, p5 * 2.00  */
// abf-on

	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(1)
	/* Each bit in K0 represents a CHAR in VEC_1.  */
	VPCMPEQ	%VEC(1), %VMATCH, %k0
	/* Each bit in K1 represents a CHAR in VEC_1.  */
	VPTESTN	%VEC(1), %VEC(1), %k1
	kortestV %k0, %k1
	jnz	L(first_vec_x2)

	/* By swapping between Method 1/2 we get more fair port
	   distrubition and better throughput.  */

	VMOVA	(VEC_SIZE * 3)(%rdi), %VEC(1)
	/* Leaves only CHARS matching esi as 0.  */
	vpxorq	%VEC(1), %VMATCH, %VEC(2)
	VPMINU	%VEC(2), %VEC(1), %VEC(2)
	/* Each bit in K0 represents a CHAR or a null byte in VEC_1.  */
	VPTESTN	%VEC(2), %VEC(2), %k0
	kmovV	%k0, %VGPR(rcx)
	test	%VGPR(rcx), %VGPR(rcx)
	jnz	L(first_vec_x3)

	VMOVA	(VEC_SIZE * 4)(%rdi), %VEC(1)
	/* Each bit in K0 represents a CHAR in VEC_1.  */
	VPCMPEQ	%VEC(1), %VMATCH, %k0
	/* Each bit in K1 represents a CHAR in VEC_1.  */
	VPTESTN	%VEC(1), %VEC(1), %k1
	kortestV %k0, %k1
	jnz	L(first_vec_x4)

	/* Align data to VEC_SIZE * 4 for the loop.  */
# if VEC_SIZE == 64
	/* Use rax for the loop reg as it allows to the loop to fit in
	   exactly 2-cache-lines. (more efficient imm32 + gpr
	   encoding).  */
	leaq	(VEC_SIZE)(%rdi), %rax
	/* No partial register stalls on evex512 processors.  */
	xorb	%al, %al
# else
	/* For VEC_SIZE == 32 continue using rdi for loop reg so we can
	   reuse more code and save space.  */
	addq	$VEC_SIZE, %rdi
	andq	$-(VEC_SIZE * 4), %rdi
# endif
	.p2align 4
L(loop_4x_vec):
	/* Check 4x VEC at a time. No penalty for imm32 offset with evex
	   encoding (if offset % VEC_SIZE == 0).  */
	VMOVA	(VEC_SIZE * 4)(%LOOP_REG), %VEC(1)
	VMOVA	(VEC_SIZE * 5)(%LOOP_REG), %VEC(2)
	VMOVA	(VEC_SIZE * 6)(%LOOP_REG), %VEC(3)
	VMOVA	(VEC_SIZE * 7)(%LOOP_REG), %VEC(4)

	/* Collect bits where VEC_1 does NOT match esi.  This is later
	   use to mask of results (getting not matches allows us to
	   save an instruction on combining).  */
	VPCMP	$4, %VMATCH, %VEC(1), %k1

	/* Two methods for loop depending on VEC_SIZE.  This is because
	   with zmm registers VPMINU can only run on p0 (as opposed to
	   p0/p1 for ymm) so it is less prefered.  */
# if VEC_SIZE == 32
	/* For VEC_2 and VEC_3 use xor to set the CHARs matching esi to
	   zero.  */
	vpxorq	%VEC(2), %VMATCH, %VEC(6)
	vpxorq	%VEC(3), %VMATCH, %VEC(7)

	/* Find non-matches in VEC_4 while combining with non-matches
	   from VEC_1.  NB: Try and use masked predicate execution on
	   instructions that have mask result as it has no latency
	   penalty.  */
	VPCMP	$4, %VMATCH, %VEC(4), %k4{%k1}

	/* Combined zeros from VEC_1 / VEC_2 (search for null term).  */
	VPMINU	%VEC(1), %VEC(2), %VEC(2)

	/* Use min to select all zeros from either xor or end of
	   string).  */
	VPMINU	%VEC(3), %VEC(7), %VEC(3)
	VPMINU	%VEC(2), %VEC(6), %VEC(2)

	/* Combined zeros from VEC_2 / VEC_3 (search for null term).  */
	VPMINU	%VEC(3), %VEC(4), %VEC(4)

	/* Combined zeros from VEC_2 / VEC_4 (this has all null term and
	   esi matches for VEC_2 / VEC_3).  */
	VPMINU	%VEC(2), %VEC(4), %VEC(4)
# else
	/* Collect non-matches for VEC_2.  */
	VPCMP	$4, %VEC(2), %VMATCH, %k2

	/* Combined zeros from VEC_1 / VEC_2 (search for null term).  */
	VPMINU	%VEC(1), %VEC(2), %VEC(2)

	/* Find non-matches in VEC_3/VEC_4 while combining with non-
	   matches from VEC_1/VEC_2 respectively.  */
	VPCMP	$4, %VEC(3), %VMATCH, %k3{%k1}
	VPCMP	$4, %VEC(4), %VMATCH, %k4{%k2}

	/* Finish combining zeros in all VECs.  */
	VPMINU	%VEC(3), %VEC(4), %VEC(4)

	/* Combine in esi matches for VEC_3 (if there was a match with
	   esi, the corresponding bit in %k3 is zero so the
	   VPMINU_MASKZ will have a zero in the result).  NB: This make
	   the VPMINU 3c latency.  The only way to avoid it is to
	   createa a 12c dependency chain on all the `VPCMP $4, ...`
	   which has higher total latency.  */
	VPMINU	%VEC(2), %VEC(4), %VEC(4){%k3}{z}
# endif
	VPTEST	%VEC(4), %VEC(4), %k0{%k4}
	kmovV	%k0, %VGPR(rdx)
	subq	$-(VEC_SIZE * 4), %LOOP_REG

	/* TESTZ is inc using the proper register width depending on
	   CHAR_PER_VEC. An esi match or null-term match leaves a zero-
	   bit in rdx so inc won't overflow and won't be zero.  */
	TESTZ	(rdx)
	jz	L(loop_4x_vec)

	VPTEST	%VEC(1), %VEC(1), %k0{%k1}
	kmovV	%k0, %VGPR(MASK_GPR)
	TESTZ	(MASK_GPR)
# if VEC_SIZE == 32
	/* We can reuse the return code in page_cross logic for VEC_SIZE
	   == 32.  */
	jnz	L(last_vec_x1_vec_size32)
# else
	jnz	L(last_vec_x1_vec_size64)
# endif


	/* COND_MASK integates the esi matches for VEC_SIZE == 64. For
	   VEC_SIZE == 32 they are already integrated.  */
	VPTEST	%VEC(2), %VEC(2), %k0 COND_MASK(k2)
	kmovV	%k0, %VGPR(rcx)
	TESTZ	(rcx)
	jnz	L(last_vec_x2)

	VPTEST	%VEC(3), %VEC(3), %k0 COND_MASK(k3)
	kmovV	%k0, %VGPR(rcx)
# if CHAR_PER_VEC == 64
	TESTZ	(rcx)
	jnz	L(last_vec_x3)
# else
	salq	$CHAR_PER_VEC, %rdx
	TESTZ	(rcx)
	orq	%rcx, %rdx
# endif

	bsfq	%rdx, %rdx

# ifndef USE_AS_STRCHRNUL
	/* Check if match was CHAR or null.  */
	cmp	(LAST_VEC_OFFSET)(%LOOP_REG, %rdx, CHAR_SIZE), %CHAR_REG
	jne	L(zero_end)
# endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(LAST_VEC_OFFSET)(%LOOP_REG, %rdx, CHAR_SIZE), %rax
	ret

# ifndef USE_AS_STRCHRNUL
L(zero_end):
	xorl	%eax, %eax
	ret
# endif


# if VEC_SIZE == 64
	.p2align 4,, 8
L(last_vec_x1_vec_size64):
	bsf	%VGPR(rcx), %VGPR(rcx)
#  ifndef USE_AS_STRCHRNUL
	/* Check if match was null.  */
	cmp	(%rax, %rcx, CHAR_SIZE), %CHAR_REG
	jne	L(zero_end)
#  endif
#  ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rax, %rcx, CHAR_SIZE), %rax
#  else
	addq	%rcx, %rax
#  endif
	ret

#  if CHAR_PER_VEC == 64
	.p2align 4,, 8
L(last_vec_x3):
	addq	$VEC_SIZE, %LOOP_REG
#  endif
L(last_vec_x2):
	bsf	%VGPR(MASK_GPR), %VGPR(MASK_GPR)
#  ifndef USE_AS_STRCHRNUL
	/* Check if match was null.  */
	cmp	(VEC_SIZE * 1)(%LOOP_REG, %MASK_GPR, CHAR_SIZE), %CHAR_REG
	jne	L(zero_end)
#  endif
	/* NB: Multiply sizeof char type (1 or 4) to get the number of
	   bytes.  */
	leaq	(VEC_SIZE * 1)(%LOOP_REG, %MASK_GPR, CHAR_SIZE), %rax
	ret
# endif

	/* Cold case for crossing page with first load.  */
	.p2align 4,, 10
L(cross_page_boundary):
	/* Align rdi.  */
	xorq	%rdi, %rax
	VMOVA	(PAGE_SIZE - VEC_SIZE)(%rax), %VEC(1)
	/* Use high latency method of getting matches to save code size.
	 */

	/* K1 has 1s where VEC(1) does NOT match esi.  */
	VPCMP	$4, %VEC(1), %VMATCH, %k1
	/* K0 has ones where K1 is 1 (non-match with esi), and non-zero
	   (null).  */
	VPTEST	%VEC(1), %VEC(1), %k0{%k1}
	kmovV	%k0, %VGPR(rax)
	/* Remove the leading bits.  */
# ifdef USE_AS_WCSCHR
	movl	%edi, %SHIFT_REG
	/* NB: Divide shift count by 4 since each bit in K1 represent 4
	   bytes.  */
	sarl	$2, %SHIFT_REG
	andl	$(CHAR_PER_VEC - 1), %SHIFT_REG

	/* if wcsrchr we need to reverse matches as we can't rely on
	   signed shift to bring in ones. There is not sarx for
	   gpr8/16. Also not we can't use inc here as the lower bits
	   represent matches out of range so we can't rely on overflow.
	 */
#  if CHAR_PER_VEC == 16
	not	%ax
#  else
	not	%al
#  endif
# endif
	/* Use arithmatic shift so that leading 1s are filled in.  */
	sarx	%VGPR(SHIFT_REG), %VGPR(rax), %VGPR(rax)
	/* If eax is all ones then no matches for esi or NULL.  */

# ifdef USE_AS_WCSCHR
	test	%VGPR(rax), %VGPR(rax)
# else
	inc	%VGPR(rax)
# endif
	jz	L(cross_page_continue)

	.p2align 4,, 10
L(last_vec_x1_vec_size32):
	bsf	%VGPR(rax), %VGPR(rax)
# ifdef USE_AS_WCSCHR
	/* NB: Multiply wchar_t count by 4 to get the number of bytes.
	 */
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	addq	%rdi, %rax
# endif
# ifndef USE_AS_STRCHRNUL
	/* Check to see if match was CHAR or null.  */
	cmp	(%rax), %CHAR_REG
	jne	L(zero_end_0)
# endif
	ret
# ifndef USE_AS_STRCHRNUL
L(zero_end_0):
	xorl	%eax, %eax
	ret
# endif

END(STRCHR)
#endif
