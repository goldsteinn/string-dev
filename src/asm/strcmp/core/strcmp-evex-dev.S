/* strcmp/wcscmp/strncmp/wcsncmp optimized with 256-bit EVEX instructions.
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
	// #define USE_AS_STRNCMP
#ifndef VEC_SIZE
# include "../../libc-defs/libc-evex-vecs.h"
#endif	/* !VEC_SIZE */
	// #define USE_AS_STRNLEN
#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# ifndef STRCMP
#  define STRCMP	__strcmp_evex
# endif

# define PAGE_SIZE	4096

	/* VEC_SIZE = Number of bytes in a ymm register.  */
# define CHAR_PER_VEC	(VEC_SIZE / SIZE_OF_CHAR)

# ifdef USE_AS_WCSCMP
#  define REG_WIDTH	32
	/* Compare packed dwords.  */
#  define VPCMP	vpcmpd
#  define VPCMPEQ	vpcmpeqd
#  define VPMINU	vpminud
#  define VPTESTM	vptestmd
#  define VPTESTNM	vptestnmd
	/* 1 dword char == 4 bytes.  */
#  define SIZE_OF_CHAR	4

#  define TESTEQ	sub $((1 << CHAR_PER_VEC) - 1),
# else
#  define REG_WIDTH	VEC_SIZE
	/* Compare packed bytes.  */
#  define VPCMP	vpcmpb
#  define VPCMPEQ	vpcmpeqb
#  define VPMINU	vpminub
#  define VPTESTM	vptestmb
#  define VPTESTNM	vptestnmb
	/* 1 byte char == 1 byte.  */
#  define SIZE_OF_CHAR	1

#  define TESTEQ	inc
# endif

# include "../../libc-defs/libc-reg-macros.h"

# if VEC_SIZE == 64
#  define RODATA_SECTION	rodata.cst64
# else
#  define RODATA_SECTION	rodata.cst32
# endif

# if CHAR_PER_VEC == 64
#  define FALLTHROUGH_RETURN_OFFSET	(VEC_SIZE * 3)
# else
#  define FALLTHROUGH_RETURN_OFFSET	(VEC_SIZE * 2)
# endif

# ifdef USE_AS_STRNCMP
#  define LOOP_REG	VR9
#  define LOOP_REG64	r9

#  define OFFSET_REG8	r9b
#  define OFFSET_REG	r9d
#  define OFFSET_REG64	r9
# else
#  define LOOP_REG	VRDX
#  define LOOP_REG64	rdx

#  define OFFSET_REG8	dl
#  define OFFSET_REG	edx
#  define OFFSET_REG64	rdx
# endif

# if defined USE_AS_STRNCMP || defined USE_AS_WCSCMP
#  define VEC_OFFSET	0
# else
#  define VEC_OFFSET	(-VEC_SIZE)
# endif

# ifdef USE_AS_STRCASECMP_L
#  define BYTE_LOOP_REG	OFFSET_REG
# else
#  define BYTE_LOOP_REG	ecx
# endif

# ifdef USE_AS_STRCASECMP_L
#  ifdef USE_AS_STRNCMP
#   define LOCALE_REG	rcx
#   define LOCALE_REG_LP	RCX_LP
#  else
#   define LOCALE_REG	rdx
#   define LOCALE_REG_LP	RDX_LP
#  endif
# endif

# define LCASE_MIN_VEC	%VEC(12)
# define LCASE_MAX_VEC	%VEC(13)
# define CASE_ADD_VEC	%VEC(14)

# if VEC_SIZE == 64
#  define LCASE_MIN_YMM	%VEC_ymm(12)
#  define LCASE_MAX_YMM	%VEC_ymm(13)
#  define CASE_ADD_YMM	%VEC_ymm(14)
# endif

# define LCASE_MIN_XMM	%VEC_xmm(12)
# define LCASE_MAX_XMM	%VEC_xmm(13)
# define CASE_ADD_XMM	%VEC_xmm(14)

	/* NB: wcsncmp uses r11 but strcasecmp is never used in
	   conjunction with wcscmp.  */
# define TOLOWER_BASE	%r11

# ifdef USE_AS_STRCASECMP_L
#  define _REG(x, y)	x ## y
#  define REG(x, y)	_REG(x, y)
#  define TOLOWER(reg1, reg2, ext, vec_macro)	\
	vpsubb	REG(LCASE_MIN_, ext), reg1, vec_macro(10);	\
	vpsubb	REG(LCASE_MIN_, ext), reg2, vec_macro(11);	\
	vpcmpub	$1, REG(LCASE_MAX_, ext), vec_macro(10), %k5;	\
	vpcmpub	$1, REG(LCASE_MAX_, ext), vec_macro(11), %k6;	\
	vpaddb	reg1, REG(CASE_ADD_, ext), reg1{%k5};	\
	vpaddb	reg2, REG(CASE_ADD_, ext), reg2{%k6}

#  define TOLOWER_gpr(src, dst)	movl (TOLOWER_BASE, src, 4), dst
#  define TOLOWER_VEC(...)	TOLOWER(__VA_ARGS__, VEC, VEC)
#  define TOLOWER_YMM(...)	TOLOWER(__VA_ARGS__, YMM, VEC_ymm)
#  define TOLOWER_XMM(...)	TOLOWER(__VA_ARGS__, XMM, VEC_xmm)

#  define CMP_R1_R2(s1_reg, s2_reg, reg_out, ext)	\
	TOLOWER	(s1_reg, s2_reg, ext);	\
	VPCMPEQ	s1_reg, s2_reg, reg_out

#  define CMP_R1_S2(s1_reg, s2_mem, s2_reg, reg_out, ext)	\
	VMOVU	s2_mem, s2_reg;	\
	CMP_R1_R2 (s1_reg, s2_reg, reg_out, ext)

#  define CMP_R1_R2_VEC(...)	CMP_R1_R2(__VA_ARGS__, VEC)
#  define CMP_R1_R2_YMM(...)	CMP_R1_R2(__VA_ARGS__, YMM)
#  define CMP_R1_R2_XMM(...)	CMP_R1_R2(__VA_ARGS__, XMM)

#  define CMP_R1_S2_VEC(...)	CMP_R1_S2(__VA_ARGS__, VEC)
#  define CMP_R1_S2_YMM(...)	CMP_R1_S2(__VA_ARGS__, YMM)
#  define CMP_R1_S2_XMM(...)	CMP_R1_S2(__VA_ARGS__, XMM)

# else
#  define TOLOWER_gpr(...)
#  define TOLOWER_VEC(...)
#  define TOLOWER_YMM(...)
#  define TOLOWER_XMM(...)

#  define CMP_R1_R2_VEC(s1_reg, s2_reg, reg_out)	\
	VPCMPEQ	s2_reg, s1_reg, reg_out

#  define CMP_R1_R2_YMM(...)	CMP_R1_R2_VEC(__VA_ARGS__)
#  define CMP_R1_R2_XMM(...)	CMP_R1_R2_VEC(__VA_ARGS__)

#  define CMP_R1_S2_VEC(s1_reg, s2_mem, unused, reg_out)	\
	VPCMPEQ	s2_mem, s1_reg, reg_out
#  define CMP_R1_S2_YMM(...)	CMP_R1_S2_VEC(__VA_ARGS__)
#  define CMP_R1_S2_XMM(...)	CMP_R1_S2_VEC(__VA_ARGS__)
# endif

	/* Warning! wcscmp/wcsncmp have to use SIGNED comparison for
	   elements. strcmp/strncmp have to use UNSIGNED comparison for
	   elements.  */


	/* The main idea of the string comparison (byte or dword) using
	   256-bit EVEX instructions consists of comparing (VPCMP) two
	   ymm vectors. The latter can be on either packed bytes or
	   dwords depending on USE_AS_WCSCMP. In order to check the
	   null CHAR, algorithm keeps the matched bytes/dwords,
	   requiring 5 EVEX instructions (3 VPCMP and 2 KORD). In
	   general, the costs of comparing VEC_SIZE bytes (32-bytes)
	   are 3 VPCMP and 2 KORD instructions, together with VMOVU and
	   ktestd instructions.  Main loop (away from from page
	   boundary) compares 4 vectors are a time, effectively
	   comparing 4 x VEC_SIZE bytes (128 bytes) on each loop. The
	   routine strncmp/wcsncmp (enabled by defining USE_AS_STRNCMP)
	   logic is the same as strcmp, except that an a maximum offset
	   is tracked.  If the maximum offset is reached before a
	   difference is found, zero is returned.  */

	.section .text.evex, "ax", @progbits
	.align	16
	.type	STRCMP, @function
	.globl	STRCMP
# ifdef USE_AS_STRCASECMP_L
ENTRY(STRCASECMP)
	movq	__libc_tsd_LOCALE@gottpoff(%rip), %rax
mov %fs:(%rax), %LOCALE_REG_LP

	/* Either 1 or 5 bytes (dependeing if CET is enabled).  */
	.p2align 4
END(STRCASECMP)
	/* FALLTHROUGH to strcasecmp/strncasecmp_l.  */
# endif

	.p2align 4
ENTRY(STRCMP)
# if defined USE_AS_STRCASECMP_L
	/* We have to fall back on the C implementation for locales with
	   encodings not matching ASCII for single bytes.  */
#  if LOCALE_T___LOCALES != 0 || LC_CTYPE != 0
	mov	LOCALE_T___LOCALES + LC_CTYPE * LP_SIZE(%LOCALE_REG), %RAX_LP
#  else
	mov	(%LOCALE_REG), %RAX_LP
#  endif
	testl	$1, LOCALE_DATA_VALUES + _NL_CTYPE_NONASCII_CASE * SIZEOF_VALUES(%rax)
	jne	STRCASECMP_L_NONASCII
	leaq	_nl_C_LC_CTYPE_tolower + 128 * 4(%rip), TOLOWER_BASE
# endif

# ifdef USE_AS_STRNCMP
	/* Don't overwrite LOCALE_REG (rcx) until we have pass
	   L(one_or_less). Otherwise we might use the wrong locale in
	   the OVERFLOW_STRCMP (strcasecmp_l).  */
#  ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%edx, %edx
#  endif
	cmp	$1, %RDX_LP
	/* Signed comparison intentional. We use this branch to also
	   test cases where length >= 2^63. These very large sizes can
	   be handled with strcmp as there is no way for that length to
	   actually bound the buffer.  */
	jle	L(one_or_less)
# endif

# if defined USE_AS_STRCASECMP_L
	.section RODATA_SECTION, "aM", @progbits, VEC_SIZE
	.align	VEC_SIZE
L(lcase_min):
	.quad	0x4141414141414141
	.quad	0x4141414141414141
	.quad	0x4141414141414141
	.quad	0x4141414141414141
#  if VEC_SIZE == 64
	.quad	0x4141414141414141
	.quad	0x4141414141414141
	.quad	0x4141414141414141
	.quad	0x4141414141414141
#  endif
L(lcase_max):
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
#  if VEC_SIZE == 64
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
	.quad	0x1a1a1a1a1a1a1a1a
#  endif
L(case_add):
	.quad	0x2020202020202020
	.quad	0x2020202020202020
	.quad	0x2020202020202020
	.quad	0x2020202020202020
#  if VEC_SIZE == 64
	.quad	0x2020202020202020
	.quad	0x2020202020202020
	.quad	0x2020202020202020
	.quad	0x2020202020202020
#  endif
	.previous

	vmovdqa64 L(lcase_min)(%rip), LCASE_MIN_VEC
	vmovdqa64 L(lcase_max)(%rip), LCASE_MAX_VEC
	vmovdqa64 L(case_add)(%rip), CASE_ADD_VEC
# endif

	movl	%edi, %eax
	orl	%esi, %eax
	/* Shift out the bits irrelivant to page boundary ([63:12]).  */
	sall	$20, %eax
	/* Check if s1 or s2 may cross a page in next 4x VEC loads.  */
	cmpl	$((PAGE_SIZE -(VEC_SIZE * 4)) << 20), %eax
	ja	L(page_cross)

L(no_page_cross):
	/* Safe to compare 4x vectors.  */
	VMOVU	(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	/* Each bit cleared in K1 represents a mismatch or a null CHAR
	   in YMM0 and 32 bytes at (%rsi).  */
	CMP_R1_S2_VEC (%VEC(0), (%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
# ifdef USE_AS_STRNCMP
	cmpq	$CHAR_PER_VEC, %rdx
	jbe	L(vec_0_test_len)
# endif

	/* TESTEQ is `incl` for strcmp/strncmp and `subl $0xff` for
	   wcscmp/wcsncmp.  */

	/* All 1s represents all equals. TESTEQ will overflow to zero in
	   all equals case. Otherwise 1s will carry until position of
	   first mismatch.  */
	TESTEQ	%VRCX
	jz	L(more_3x_vec)

	.p2align 4,, 4
L(return_vec_0):
	bsf	%VRCX, %VRCX
# ifdef USE_AS_WCSCMP
	movl	(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret0)
	setl	%al
	negl	%eax
	orl	$1, %eax
# else
	movzbl	(%rdi, %rcx), %eax
#  if !defined USE_AS_STRNCMP && !defined USE_AS_STRCASECMP_L && VEC_SIZE == 64
	movb	(%rsi, %rcx), %cl
#  else
	movzbl	(%rsi, %rcx), %ecx
#  endif
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
# endif
L(ret0):
	ret

# ifdef USE_AS_STRNCMP
	.p2align 4,, 4
L(vec_0_test_len):
	not	%VRCX
	bzhi	%VRDX, %VRCX, %VRAX
	jnz	L(return_vec_0)
	/* Align if will cross fetch block.  */
	.p2align 4,, 2
L(ret_zero):
	xorl	%eax, %eax
	ret

	.p2align 4,, 5
L(one_or_less):
#  ifdef USE_AS_STRCASECMP_L
	/* Set locale argument for strcasecmp.  */
	movq	%LOCALE_REG, %rdx
#  endif
	jb	L(ret_zero)
	/* 'nbe' covers the case where length is negative (large
	   unsigned).  */
	jnbe	OVERFLOW_STRCMP
#  ifdef USE_AS_WCSCMP
	movl	(%rdi), %edx
	xorl	%eax, %eax
	cmpl	(%rsi), %edx
	je	L(ret1)
	setl	%al
	negl	%eax
	orl	$1, %eax
#  else
	movzbl	(%rdi), %eax
	movzbl	(%rsi), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
#  endif
L(ret1):
	ret
# endif

	.p2align 4,, 10
L(return_vec_1):
	bsf	%VRCX, %VRCX
# ifdef USE_AS_STRNCMP
	/* rdx must be > CHAR_PER_VEC so its safe to subtract without
	   worrying about underflow.  */
	addq	$-CHAR_PER_VEC, %rdx
	cmpq	%rcx, %rdx
	jbe	L(ret_zero)
# endif
# ifdef USE_AS_WCSCMP
	movl	VEC_SIZE(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	VEC_SIZE(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret2)
	setl	%al
	negl	%eax
	orl	$1, %eax
# else
	movzbl	VEC_SIZE(%rdi, %rcx), %eax
	movzbl	VEC_SIZE(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
# endif
L(ret2):
	ret

	.p2align 4,, 10
# ifdef USE_AS_STRNCMP
L(return_vec_3):
#  if CHAR_PER_VEC <= 32
#   if CHAR_PER_VEC <= 16
	sall	$CHAR_PER_VEC, %ecx
#   else
	salq	$CHAR_PER_VEC, %rcx
#   endif
#  else
	bsf	%VRCX, %VRCX
	addl	$(CHAR_PER_VEC), %ecx
	cmpq	%rcx, %rdx
	ja	L(ret_vec_3_finish)
	xorl	%eax, %eax
	ret
#  endif
# endif

# if CHAR_PER_VEC == 64 && !defined USE_AS_STRNCMP
L(return_vec_2_end):
# endif
L(return_vec_2):
# if (CHAR_PER_VEC <= 16) || !(defined USE_AS_STRNCMP)
	bsf	%VRCX, %VRCX
# else
	bsfq	%rcx, %rcx
# endif
# ifdef USE_AS_STRNCMP
	cmpq	%rcx, %rdx
	jbe	L(ret_zero)
# endif

L(ret_vec_3_finish):
# ifdef USE_AS_WCSCMP
	movl	(VEC_SIZE * 2)(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(VEC_SIZE * 2)(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret3)
	setl	%al
	negl	%eax
	orl	$1, %eax
# else
	movzbl	(VEC_SIZE * 2)(%rdi, %rcx), %eax
	movzbl	(VEC_SIZE * 2)(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
# endif
L(ret3):
	ret

# ifndef USE_AS_STRNCMP
	.p2align 4,, 7
L(return_vec_3):
	bsf	%VRCX, %VRCX
#  ifdef USE_AS_WCSCMP
	movl	(VEC_SIZE * 3)(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(VEC_SIZE * 3)(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret4)
	setl	%al
	negl	%eax
	orl	$1, %eax
#  else
	movzbl	(VEC_SIZE * 3)(%rdi, %rcx), %eax
	movzbl	(VEC_SIZE * 3)(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
#  endif
L(ret4):
	ret
# endif

	/* 32 byte align here ensures the main loop is ideally aligned
	   for DSB.  */
	.p2align 4
L(more_3x_vec):
	/* Safe to compare 4x vectors.  */
	VMOVU	(VEC_SIZE)(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), VEC_SIZE(%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_1)

# ifdef USE_AS_STRNCMP
	subq	$(CHAR_PER_VEC * 2), %rdx
	jbe	L(ret_zero)
# endif

	VMOVU	(VEC_SIZE * 2)(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), (VEC_SIZE * 2)(%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_2)

	VMOVU	(VEC_SIZE * 3)(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), (VEC_SIZE * 3)(%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_3)

# ifdef USE_AS_STRNCMP
	cmpq	$(CHAR_PER_VEC * 2), %rdx
	jbe	L(ret_zero)
# endif


# ifdef USE_AS_WCSCMP
	/* any non-zero positive value that doesn't inference with 0x1.
	 */
	movl	$2, %r8d

# else
	xorl	%r8d, %r8d
# endif

	/* The prepare labels are various entry points from the page
	   cross logic.  */
L(prepare_loop):

# ifdef USE_AS_STRNCMP
#  ifdef USE_AS_WCSCMP
L(prepare_loop_no_len):
	movl	%edi, %ecx
	andl	$(VEC_SIZE * 4 - 1), %ecx
	shrl	$2, %ecx
	leaq	(CHAR_PER_VEC * 2)(%rdx, %rcx), %rdx
#  else
	/* Store N + (VEC_SIZE * 4) and place check at the begining of
	   the loop.  */
	leaq	(VEC_SIZE * 2)(%rdi, %rdx), %rdx
L(prepare_loop_no_len):
#  endif
# else
L(prepare_loop_no_len):
# endif

	/* Align s1 and adjust s2 accordingly.  */
	subq	%rdi, %rsi
	andq	$-(VEC_SIZE * 4), %rdi
L(prepare_loop_readj):
	addq	%rdi, %rsi
# if (defined USE_AS_STRNCMP) && !(defined USE_AS_WCSCMP)
	subq	%rdi, %rdx
# endif

L(prepare_loop_aligned):
	/* eax stores distance from rsi to next page cross. These cases
	   need to be handled specially as the 4x loop could
	   potentially read memory past the length of s1 or s2 and
	   across a page boundary.  */
	movl	$-(VEC_SIZE * 4), %eax
	subl	%esi, %eax
	andl	$(PAGE_SIZE - 1), %eax


	/* Loop 4x comparisons at a time.  */
	.p2align 4
L(loop):

	/* End condition for strncmp.  */
# ifdef USE_AS_STRNCMP
	subq	$(CHAR_PER_VEC * 4), %rdx
	jbe	L(ret_zero)
# endif

	subq	$-(VEC_SIZE * 4), %rdi
	subq	$-(VEC_SIZE * 4), %rsi

	/* Check if rsi loads will cross a page boundary.  */
	addl	$-(VEC_SIZE * 4), %eax
	jnb	L(page_cross_during_loop)

	/* Loop entry after handling page cross during loop.  */
L(loop_skip_page_cross_check):
	VMOVA	(VEC_SIZE * 0)(%rdi), %VEC(0)
	VMOVA	(VEC_SIZE * 1)(%rdi), %VEC(2)
	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(4)
	VMOVA	(VEC_SIZE * 3)(%rdi), %VEC(6)

	VPMINU	%VEC(0), %VEC(2), %VEC(8)
	VPMINU	%VEC(4), %VEC(6), %VEC(9)

	/* A zero CHAR in YMM9 means that there is a null CHAR.  */
	VPMINU	%VEC(8), %VEC(9), %VEC(9)

	/* Each bit set in K1 represents a non-null CHAR in YMM9.  */
	VPTESTM	%VEC(9), %VEC(9), %k1
# ifndef USE_AS_STRCASECMP_L
	vpxorq	(VEC_SIZE * 0)(%rsi), %VEC(0), %VEC(1)
	vpxorq	(VEC_SIZE * 1)(%rsi), %VEC(2), %VEC(3)
	vpxorq	(VEC_SIZE * 2)(%rsi), %VEC(4), %VEC(5)
	/* Ternary logic to xor (VEC_SIZE * 3)(%rsi) with YMM6 while
	   oring with YMM1. Result is stored in YMM6.  */
	vpternlogd $0xde, (VEC_SIZE * 3)(%rsi), %VEC(1), %VEC(6)
# else
	VMOVU	(VEC_SIZE * 0)(%rsi), %VEC(1)
	TOLOWER_VEC (%VEC(0), %VEC(1))
	VMOVU	(VEC_SIZE * 1)(%rsi), %VEC(3)
	TOLOWER_VEC (%VEC(2), %VEC(3))
	VMOVU	(VEC_SIZE * 2)(%rsi), %VEC(5)
	TOLOWER_VEC (%VEC(4), %VEC(5))
	VMOVU	(VEC_SIZE * 3)(%rsi), %VEC(7)
	TOLOWER_VEC (%VEC(6), %VEC(7))
	vpxorq	%VEC(0), %VEC(1), %VEC(1)
	vpxorq	%VEC(2), %VEC(3), %VEC(3)
	vpxorq	%VEC(4), %VEC(5), %VEC(5)
	vpternlogd $0xde, %VEC(7), %VEC(1), %VEC(6)
# endif
	/* Or together YMM3, YMM5, and YMM6.  */
	vpternlogd $0xfe, %VEC(3), %VEC(5), %VEC(6)


	/* A non-zero CHAR in YMM6 represents a mismatch.  */
	VPTESTNM %VEC(6), %VEC(6), %k0{%k1}
	kmovV	%k0, %LOOP_REG

	TESTEQ	%LOOP_REG
	jz	L(loop)


	/* Find which VEC has the mismatch of end of string.  */
	VPTESTM	%VEC(0), %VEC(0), %k1
	VPTESTNM %VEC(1), %VEC(1), %k0{%k1}
	kmovV	%k0, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_0_end)

	VPTESTM	%VEC(2), %VEC(2), %k1
	VPTESTNM %VEC(3), %VEC(3), %k0{%k1}
	kmovV	%k0, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_1_end)


	/* Handle VEC 2 and 3 without branches if CHAR_PER_VEC <= 32.
	 */
L(return_vec_2_3_end):
# ifdef USE_AS_STRNCMP
	subq	$(CHAR_PER_VEC * 2), %rdx
	jbe	L(ret_zero_end)
# endif

	VPTESTM	%VEC(4), %VEC(4), %k1
	VPTESTNM %VEC(5), %VEC(5), %k0{%k1}
	kmovV	%k0, %VRCX
	TESTEQ	%VRCX
# if CHAR_PER_VEC <= 16
	sall	$CHAR_PER_VEC, %LOOP_REG
	orl	%ecx, %LOOP_REG
# elif CHAR_PER_VEC <= 32
	salq	$CHAR_PER_VEC, %LOOP_REG64
	orq	%rcx, %LOOP_REG64
# else
	jnz	L(return_vec_2_end)
# endif

	/* LOOP_REG contains matches for null/mismatch from the loop. If
	   VEC 0,1,and 2 all have no null and no mismatches then
	   mismatch must entirely be from VEC 3 which is fully
	   represented by LOOP_REG.  */
# if CHAR_PER_VEC <= 16
	bsf	%LOOP_REG, %LOOP_REG
# else
	bsfq	%LOOP_REG64, %LOOP_REG64
# endif
# ifdef USE_AS_STRNCMP

#  if CHAR_PER_VEC == 64
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(ret_zero_end)
#  endif

	cmpq	%LOOP_REG64, %rdx
	jbe	L(ret_zero_end)
# endif

# ifdef USE_AS_WCSCMP
	movl	(FALLTHROUGH_RETURN_OFFSET)(%rdi, %LOOP_REG64, SIZE_OF_CHAR), %ecx
	xorl	%eax, %eax
	cmpl	(FALLTHROUGH_RETURN_OFFSET)(%rsi, %LOOP_REG64, SIZE_OF_CHAR), %ecx
	je	L(ret5)
	setl	%al
	negl	%eax
	xorl	%r8d, %eax
# else
	movzbl	(FALLTHROUGH_RETURN_OFFSET)(%rdi, %LOOP_REG64), %eax
	movzbl	(FALLTHROUGH_RETURN_OFFSET)(%rsi, %LOOP_REG64), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	xorl	%r8d, %eax
	subl	%r8d, %eax
# endif
L(ret5):
	ret

# ifdef USE_AS_STRNCMP
	.p2align 4,, 2
L(ret_zero_end):
	xorl	%eax, %eax
	ret
# endif



	/* The L(return_vec_N_end) differ from L(return_vec_N) in that
	   they use the value of `r8` to negate the return value. This
	   is because the page cross logic can swap `rdi` and `rsi`.
	 */
	.p2align 4,, 10
# ifdef USE_AS_STRNCMP
L(return_vec_1_end):
#  if CHAR_PER_VEC <= 32
#   if CHAR_PER_VEC <= 16
	sall	$CHAR_PER_VEC, %ecx
#   else
	salq	$CHAR_PER_VEC, %rcx
#   endif
#  else
	bsf	%VRCX, %VRCX
	addl	$(CHAR_PER_VEC), %ecx
	cmpq	%rcx, %rdx
	ja	L(ret_vec_0_end_finish)
	xorl	%eax, %eax
	ret
#  endif
# endif
L(return_vec_0_end):
# if (CHAR_PER_VEC <= 16) || !(defined USE_AS_STRNCMP)
	bsf	%VRCX, %VRCX
# else
	bsfq	%rcx, %rcx
# endif

# ifdef USE_AS_STRNCMP
	cmpq	%rcx, %rdx
	jbe	L(ret_zero_end)
# endif

L(ret_vec_0_end_finish):
# ifdef USE_AS_WCSCMP
	movl	(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret6)
	setl	%al
	negl	%eax
	/* This is the non-zero case for `eax` so just xorl with `r8d`
	   flip is `rdi` and `rsi` where swapped.  */
	xorl	%r8d, %eax
# else
	movzbl	(%rdi, %rcx), %eax
	movzbl	(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	/* Flip `eax` if `rdi` and `rsi` where swapped in page cross
	   logic. Subtract `r8d` after xor for zero case.  */
	xorl	%r8d, %eax
	subl	%r8d, %eax
# endif
L(ret6):
	ret

# ifndef USE_AS_STRNCMP
	.p2align 4,, 10
L(return_vec_1_end):
	bsf	%VRCX, %VRCX
#  ifdef USE_AS_WCSCMP
	movl	VEC_SIZE(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	VEC_SIZE(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret7)
	setl	%al
	negl	%eax
	xorl	%r8d, %eax
#  else
	movzbl	VEC_SIZE(%rdi, %rcx), %eax
	movzbl	VEC_SIZE(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	xorl	%r8d, %eax
	subl	%r8d, %eax
#  endif
L(ret7):
	ret
# endif

# if CHAR_PER_VEC == 64 && defined USE_AS_STRNCMP
L(return_vec_2_end):
	bsfq	%rcx, %rcx

	cmpq	%rcx, %rdx
	jbe	L(ret_zero_end)

#  ifdef USE_AS_WCSCMP
	movl	(VEC_SIZE * 2)(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(VEC_SIZE * 2)(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret31)
	setl	%al
	negl	%eax
	/* This is the non-zero case for `eax` so just xorl with `r8d`
	   flip is `rdi` and `rsi` where swapped.  */
	xorl	%r8d, %eax
#  else
	movzbl	(VEC_SIZE * 2)(%rdi, %rcx), %eax
	movzbl	(VEC_SIZE * 2)(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	/* Flip `eax` if `rdi` and `rsi` where swapped in page cross
	   logic. Subtract `r8d` after xor for zero case.  */
	xorl	%r8d, %eax
	subl	%r8d, %eax
#  endif
L(ret13):
	ret
# endif


	/* Page cross in rsi in next 4x VEC.  */

	/* TODO: Improve logic here.  */
	.p2align 4,, 10
L(page_cross_during_loop):
	/* eax contains [distance_from_page - (VEC_SIZE * 4)].  */

	/* Optimistically rsi and rdi and both aligned in which case we
	   don't need any logic here.  */
	cmpl	$-(VEC_SIZE * 4), %eax
	/* Don't adjust eax before jumping back to loop and we will
	   never hit page cross case again.  */
	je	L(loop_skip_page_cross_check)

	/* Check if we can safely load a VEC.  */
	cmpl	$-(VEC_SIZE * 3), %eax
	jle	L(less_1x_vec_till_page_cross)

	VMOVA	(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), (%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_0_end)

	/* if distance >= 2x VEC then eax > -(VEC_SIZE * 2).  */
	cmpl	$-(VEC_SIZE * 2), %eax
	jg	L(more_2x_vec_till_page_cross)

	.p2align 4,, 4
L(less_1x_vec_till_page_cross):
	subl	$-(VEC_SIZE * 4), %eax
	/* Guranteed safe to read from rdi - VEC_SIZE here. The only
	   concerning case is first iteration if incoming s1 was near
	   start of a page and s2 near end. If s1 was near the start of
	   the page we already aligned up to nearest VEC_SIZE * 4 so
	   gurnateed safe to read back -VEC_SIZE. If rdi is truly at
	   the start of a page here, it means the previous page (rdi -
	   VEC_SIZE) has already been loaded earlier so must be valid.
	 */
	VMOVU	-VEC_SIZE(%rdi, %rax), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), -VEC_SIZE(%rsi, %rax), %VEC(1), %k1){%k2}
	/* Mask of potentially valid bits. The lower bits can be out of
	   range comparisons (but safe regarding page crosses).  */

# ifdef USE_AS_WCSCMP
	movl	$-1, %r10d
	movl	%esi, %ecx
	andl	$(VEC_SIZE - 1), %ecx
	shrl	$2, %ecx
	shlxl	%ecx, %r10d, %ecx
	movzbl	%cl, %r10d
# else
	mov	$-1, %VRCX
	shlx	%VRSI, %VRCX, %VR10
# endif

	kmovV	%k1, %VRCX
	not	%VRCX


# ifdef USE_AS_STRNCMP
#  ifdef USE_AS_WCSCMP
	/* NB: strcasecmp not used with WCSCMP so this access to r11 is
	   safe.  */
	movl	%eax, %r11d
	shrl	$2, %r11d
	cmpq	%r11, %rdx
#  else
	cmpq	%rax, %rdx
#  endif
	jbe	L(return_page_cross_end_check)
# endif
	movl	%eax, %OFFSET_REG

	/* Readjust eax before potentially returning to the loop.  */
	addl	$(PAGE_SIZE - VEC_SIZE * 4), %eax

	and	%VR10, %VRCX
	jz	L(loop_skip_page_cross_check)

	.p2align 4,, 3
L(return_page_cross_end):
	bsf	%VRCX, %VRCX

# if (defined USE_AS_STRNCMP) || (defined USE_AS_WCSCMP)
	leal	-VEC_SIZE(%OFFSET_REG64, %rcx, SIZE_OF_CHAR), %ecx
L(return_page_cross_cmp_mem):
# else
	addl	%OFFSET_REG, %ecx
# endif
# ifdef USE_AS_WCSCMP
	movl	VEC_OFFSET(%rdi, %rcx), %edx
	xorl	%eax, %eax
	cmpl	VEC_OFFSET(%rsi, %rcx), %edx
	je	L(ret8)
	setl	%al
	negl	%eax
	xorl	%r8d, %eax
# else
	movzbl	VEC_OFFSET(%rdi, %rcx), %eax
	movzbl	VEC_OFFSET(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	xorl	%r8d, %eax
	subl	%r8d, %eax
# endif
L(ret8):
	ret

# ifdef USE_AS_STRNCMP
	.p2align 4,, 10
L(return_page_cross_end_check):
	and	%VR10, %VRCX
	bsf	%VRCX, %VRCX
	leal	-VEC_SIZE(%rax, %rcx, SIZE_OF_CHAR), %ecx
#  ifdef USE_AS_WCSCMP
	sall	$2, %edx
#  endif
	cmpl	%ecx, %edx
	ja	L(return_page_cross_cmp_mem)
	xorl	%eax, %eax
	ret
# endif


	.p2align 4,, 10
L(more_2x_vec_till_page_cross):
	/* If more 2x vec till cross we will complete a full loop
	   iteration here.  */

	VMOVA	VEC_SIZE(%rdi), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), VEC_SIZE(%rsi), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_1_end)

# ifdef USE_AS_STRNCMP
	cmpq	$(CHAR_PER_VEC * 2), %rdx
	jbe	L(ret_zero_in_loop_page_cross)
# endif

	subl	$-(VEC_SIZE * 4), %eax

	/* Safe to include comparisons from lower bytes.  */
	VMOVU	-(VEC_SIZE * 2)(%rdi, %rax), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), -(VEC_SIZE * 2)(%rsi, %rax), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_page_cross_0)

	VMOVU	-(VEC_SIZE * 1)(%rdi, %rax), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), -(VEC_SIZE * 1)(%rsi, %rax), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(return_vec_page_cross_1)

# ifdef USE_AS_STRNCMP
	/* Must check length here as length might proclude reading next
	   page.  */
#  ifdef USE_AS_WCSCMP
	/* NB: strcasecmp not used with WCSCMP so this access to r11 is
	   safe.  */
	movl	%eax, %r11d
	shrl	$2, %r11d
	cmpq	%r11, %rdx
#  else
	cmpq	%rax, %rdx
#  endif
	jbe	L(ret_zero_in_loop_page_cross)
# endif

	/* Finish the loop.  */
	VMOVA	(VEC_SIZE * 2)(%rdi), %VEC(4)
	VMOVA	(VEC_SIZE * 3)(%rdi), %VEC(6)
	VPMINU	%VEC(4), %VEC(6), %VEC(9)
	VPTESTM	%VEC(9), %VEC(9), %k1
# ifndef USE_AS_STRCASECMP_L
	vpxorq	(VEC_SIZE * 2)(%rsi), %VEC(4), %VEC(5)
	/* YMM6 = YMM5 | ((VEC_SIZE * 3)(%rsi) ^ YMM6).  */
	vpternlogd $0xde, (VEC_SIZE * 3)(%rsi), %VEC(5), %VEC(6)
# else
	VMOVU	(VEC_SIZE * 2)(%rsi), %VEC(5)
	TOLOWER_VEC (%VEC(4), %VEC(5))
	VMOVU	(VEC_SIZE * 3)(%rsi), %VEC(7)
	TOLOWER_VEC (%VEC(6), %VEC(7))
	vpxorq	%VEC(4), %VEC(5), %VEC(5)
	vpternlogd $0xde, %VEC(7), %VEC(5), %VEC(6)
# endif
	VPTESTNM %VEC(6), %VEC(6), %k0{%k1}
	kmovV	%k0, %LOOP_REG
	TESTEQ	%LOOP_REG
	jnz	L(return_vec_2_3_end)

	/* Best for code size to include ucond-jmp here. Would be faster
	   if this case is hot to duplicate the L(return_vec_2_3_end)
	   code as fall-through and have jump back to loop on mismatch
	   comparison.  */
	subq	$-(VEC_SIZE * 4), %rdi
	subq	$-(VEC_SIZE * 4), %rsi
	addl	$(PAGE_SIZE - VEC_SIZE * 8), %eax
# ifdef USE_AS_STRNCMP
	subq	$(CHAR_PER_VEC * 4), %rdx
	ja	L(loop_skip_page_cross_check)
L(ret_zero_in_loop_page_cross):
	xorl	%eax, %eax
	ret
# else
	jmp	L(loop_skip_page_cross_check)
# endif


	.p2align 4,, 10
L(return_vec_page_cross_0):
	addl	$-VEC_SIZE, %eax
L(return_vec_page_cross_1):
	bsf	%VRCX, %VRCX
# if defined USE_AS_STRNCMP || defined USE_AS_WCSCMP
	leal	-VEC_SIZE(%rax, %rcx, SIZE_OF_CHAR), %ecx
#  ifdef USE_AS_STRNCMP
#   ifdef USE_AS_WCSCMP
	/* Must divide ecx instead of multiply rdx due to overflow.  */
	movl	%ecx, %eax
	shrl	$2, %eax
	cmpq	%rax, %rdx
#   else
	cmpq	%rcx, %rdx
#   endif
	jbe	L(ret_zero_in_loop_page_cross)
#  endif
# else
	addl	%eax, %ecx
# endif

# ifdef USE_AS_WCSCMP
	movl	VEC_OFFSET(%rdi, %rcx), %edx
	xorl	%eax, %eax
	cmpl	VEC_OFFSET(%rsi, %rcx), %edx
	je	L(ret9)
	setl	%al
	negl	%eax
	xorl	%r8d, %eax
# else
	movzbl	VEC_OFFSET(%rdi, %rcx), %eax
	movzbl	VEC_OFFSET(%rsi, %rcx), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	xorl	%r8d, %eax
	subl	%r8d, %eax
# endif
L(ret9):
	ret


	.p2align 4,, 10
L(page_cross):
# ifndef USE_AS_STRNCMP
	/* If both are VEC aligned we don't need any special logic here.
	   Only valid for strcmp where stop condition is guranteed to
	   be reachable by just reading memory.  */
	testl	$((VEC_SIZE - 1) << 20), %eax
	jz	L(no_page_cross)
# endif

	movl	%edi, %eax
	movl	%esi, %ecx
	andl	$(PAGE_SIZE - 1), %eax
	andl	$(PAGE_SIZE - 1), %ecx

	xorl	%OFFSET_REG, %OFFSET_REG

	/* Check which is closer to page cross, s1 or s2.  */
	cmpl	%eax, %ecx
	jg	L(page_cross_s2)

	/* The previous page cross check has false positives. Check for
	   true positive as page cross logic is very expensive.  */
	subl	$(PAGE_SIZE - VEC_SIZE * 4), %eax
	jbe	L(no_page_cross)


	/* Set r8 to not interfere with normal return value (rdi and rsi
	   did not swap).  */
# ifdef USE_AS_WCSCMP
	/* any non-zero positive value that doesn't inference with 0x1.
	 */
	movl	$2, %r8d
# else
	xorl	%r8d, %r8d
# endif

	/* Check if less than 1x VEC till page cross.  */
	subl	$(VEC_SIZE * 3), %eax
	jg	L(less_1x_vec_till_page)


	/* If more than 1x VEC till page cross, loop throuh safely
	   loadable memory until within 1x VEC of page cross.  */
	.p2align 4,, 8
L(page_cross_loop):
	VMOVU	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), (%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC(1), %k1){%k2}
	kmovV	%k1, %VRCX
	TESTEQ	%VRCX
	jnz	L(check_ret_vec_page_cross)
	addl	$CHAR_PER_VEC, %OFFSET_REG
# ifdef USE_AS_STRNCMP
	cmpq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross)
# endif
	addl	$VEC_SIZE, %eax
	jl	L(page_cross_loop)

# ifdef USE_AS_WCSCMP
	shrl	$2, %eax
# endif


	subl	%eax, %OFFSET_REG
	/* OFFSET_REG has distance to page cross - VEC_SIZE. Guranteed
	   to not cross page so is safe to load. Since we have already
	   loaded at least 1 VEC from rsi it is also guranteed to be
	   safe.  */
	VMOVU	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC(0)
	VPTESTM	%VEC(0), %VEC(0), %k2
	CMP_R1_S2_VEC (%VEC(0), (%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC(1), %k1){%k2}

	kmovV	%k1, %VRCX
# ifdef USE_AS_STRNCMP
	leal	CHAR_PER_VEC(%OFFSET_REG64), %eax
	cmpq	%rax, %rdx
	jbe	L(check_ret_vec_page_cross2)
#  ifdef USE_AS_WCSCMP
	addq	$-(CHAR_PER_VEC * 2), %rdx
#  else
	addq	%rdi, %rdx
#  endif
# endif
	TESTEQ	%VRCX
	jz	L(prepare_loop_no_len)

	.p2align 4,, 4
L(ret_vec_page_cross):
# ifndef USE_AS_STRNCMP
L(check_ret_vec_page_cross):
# endif
	bsf	%VRCX, %VRCX
	addl	%OFFSET_REG, %ecx
L(ret_vec_page_cross_cont):
# ifdef USE_AS_WCSCMP
	movl	(%rdi, %rcx, SIZE_OF_CHAR), %edx
	xorl	%eax, %eax
	cmpl	(%rsi, %rcx, SIZE_OF_CHAR), %edx
	je	L(ret12)
	setl	%al
	negl	%eax
	xorl	%r8d, %eax
# else
	movzbl	(%rdi, %rcx, SIZE_OF_CHAR), %eax
	movzbl	(%rsi, %rcx, SIZE_OF_CHAR), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %ecx)
	subl	%ecx, %eax
	xorl	%r8d, %eax
	subl	%r8d, %eax
# endif
L(ret12):
	ret


# ifdef USE_AS_STRNCMP
	.p2align 4,, 10
L(check_ret_vec_page_cross2):
	TESTEQ	%VRCX
L(check_ret_vec_page_cross):
	bsf	%VRCX, %VRCX
	addl	%OFFSET_REG, %ecx
	cmpq	%rcx, %rdx
	ja	L(ret_vec_page_cross_cont)
	.p2align 4,, 2
L(ret_zero_page_cross):
	xorl	%eax, %eax
	ret
# endif

	.p2align 4,, 4
L(page_cross_s2):
	/* Ensure this is a true page cross.  */
	subl	$(PAGE_SIZE - VEC_SIZE * 4), %ecx
	jbe	L(no_page_cross)


	movl	%ecx, %eax
	movq	%rdi, %rcx
	movq	%rsi, %rdi
	movq	%rcx, %rsi

	/* set r8 to negate return value as rdi and rsi swapped.  */
# ifdef USE_AS_WCSCMP
	movl	$-4, %r8d
# else
	movl	$-1, %r8d
# endif
	xorl	%OFFSET_REG, %OFFSET_REG

	/* Check if more than 1x VEC till page cross.  */
	subl	$(VEC_SIZE * 3), %eax
	jle	L(page_cross_loop)

	.p2align 4,, 6
L(less_1x_vec_till_page):

# ifdef USE_AS_WCSCMP
	shrl	$2, %eax
# endif

# if VEC_SIZE == 64
	/* Find largest load size we can use.  */
	cmpl	$((VEC_SIZE - 32) / SIZE_OF_CHAR), %eax
	ja	L(less_32_till_page)


	/* Use 16 byte comparison.  */
	VMOVU	(%rdi), %VEC_ymm(0)
	VPTESTM	%VEC_ymm(0), %VEC_ymm(0), %k2
	CMP_R1_S2_YMM (%VEC_ymm(0), (%rsi), %VEC_ymm(1), %k1){%k2}
	kmovV	%k1, %VRCX
#  ifdef USE_AS_WCSCMP
	subl	$0xff, %ecx
#  else
	incl	%ecx
#  endif
	jnz	L(check_ret_vec_page_cross)
	movl	$((VEC_SIZE - 32) / SIZE_OF_CHAR), %OFFSET_REG
#  ifdef USE_AS_STRNCMP
	cmpq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case64)
	subl	%eax, %OFFSET_REG
#  else
	/* Explicit check for 32 byte alignment.  */
	subl	%eax, %OFFSET_REG
	jz	L(prepare_loop)
#  endif
	VMOVU	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC_ymm(0)
	VPTESTM	%VEC_ymm(0), %VEC_ymm(0), %k2
	CMP_R1_S2_YMM (%VEC_ymm(0), (%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %VEC_ymm(1), %k1){%k2}
	kmovV	%k1, %VRCX
#  ifdef USE_AS_WCSCMP
	subl	$0xf, %ecx
#  else
	incw	%cx
#  endif
	jnz	L(check_ret_vec_page_cross)
#  ifdef USE_AS_STRNCMP
	addl	$(32 / SIZE_OF_CHAR), %OFFSET_REG
	subq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case64)
	subq	$-(CHAR_PER_VEC * 4), %rdx

	leaq	-(VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	-(VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
#  else
	leaq	(32 - VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	(32 - VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
#  endif
	jmp	L(prepare_loop_aligned)

#  ifdef USE_AS_STRNCMP
	.p2align 4,, 2
L(ret_zero_page_cross_slow_case64):
	xorl	%eax, %eax
	ret
#  endif
L(less_32_till_page):
# endif

	/* Find largest load size we can use.  */
	cmpl	$((VEC_SIZE - 16) / SIZE_OF_CHAR), %eax
	ja	L(less_16_till_page)

	/* Use 16 byte comparison.  */
	vmovdqu	(%rdi), %xmm0
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_S2_XMM (%xmm0, (%rsi), %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
# ifdef USE_AS_WCSCMP
	subl	$0xf, %ecx
# else
	incw	%cx
# endif
	jnz	L(check_ret_vec_page_cross)
	movl	$((VEC_SIZE - 16) / SIZE_OF_CHAR), %OFFSET_REG
# ifdef USE_AS_STRNCMP
	cmpq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case0)
	subl	%eax, %OFFSET_REG
# else
	/* Explicit check for 16 byte alignment.  */
	subl	%eax, %OFFSET_REG
	jz	L(prepare_loop)
# endif
	vmovdqu	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm0
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_S2_XMM (%xmm0, (%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
# ifdef USE_AS_WCSCMP
	subl	$0xf, %ecx
# else
	incw	%cx
# endif
	jnz	L(check_ret_vec_page_cross)
# ifdef USE_AS_STRNCMP
	addl	$(16 / SIZE_OF_CHAR), %OFFSET_REG
	subq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case0)
	subq	$-(CHAR_PER_VEC * 4), %rdx

	leaq	-(VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	-(VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
# else
	leaq	(16 - VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	(16 - VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
# endif
	jmp	L(prepare_loop_aligned)

# ifdef USE_AS_STRNCMP
	.p2align 4,, 2
L(ret_zero_page_cross_slow_case0):
	xorl	%eax, %eax
	ret
# endif


	.p2align 4,, 10
L(less_16_till_page):
	cmpl	$((VEC_SIZE - 8) / SIZE_OF_CHAR), %eax
	ja	L(less_8_till_page)

	/* Use 8 byte comparison.  */
	vmovq	(%rdi), %xmm0
	vmovq	(%rsi), %xmm1
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_R2_XMM (%xmm0, %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
# ifdef USE_AS_WCSCMP
	subl	$0x3, %ecx
# else
	incb	%cl
# endif
	jnz	L(check_ret_vec_page_cross)


# ifdef USE_AS_STRNCMP
	cmpq	$(8 / SIZE_OF_CHAR), %rdx
	jbe	L(ret_zero_page_cross_slow_case0)
# endif
	movl	$((VEC_SIZE - 8) / SIZE_OF_CHAR), %OFFSET_REG
	subl	%eax, %OFFSET_REG

	vmovq	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm0
	vmovq	(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm1
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_R2_XMM (%xmm0, %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
# ifdef USE_AS_WCSCMP
	subl	$0x3, %ecx
# else
	incb	%cl
# endif
	jnz	L(check_ret_vec_page_cross)


# ifdef USE_AS_STRNCMP
	addl	$(8 / SIZE_OF_CHAR), %OFFSET_REG
	subq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case0)
	subq	$-(CHAR_PER_VEC * 4), %rdx

	leaq	-(VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	-(VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
# else
	leaq	(8 - VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	(8 - VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
# endif
	jmp	L(prepare_loop_aligned)




	.p2align 4,, 10
L(less_8_till_page):
# ifdef USE_AS_WCSCMP
	/* If using wchar then this is the only check before we reach
	   the page boundary.  */
	movl	(%rdi), %eax
	movl	(%rsi), %ecx
	cmpl	%ecx, %eax
	jnz	L(ret_less_8_wcs)
#  ifdef USE_AS_STRNCMP
	addq	$-(CHAR_PER_VEC * 2), %rdx
	/* We already checked for len <= 1 so cannot hit that case here.
	 */
#  endif
	testl	%eax, %eax
	jnz	L(prepare_loop)
	ret

	.p2align 4,, 8
L(ret_less_8_wcs):
	setl	%OFFSET_REG8
	negl	%OFFSET_REG
	movl	%OFFSET_REG, %eax
	xorl	%r8d, %eax
	ret

# else
	cmpl	$(VEC_SIZE - 4), %eax
	ja	L(less_4_till_page)

	vmovd	(%rdi), %xmm0
	vmovd	(%rsi), %xmm1
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_R2_XMM (%xmm0, %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
	subl	$0xf, %ecx
	jnz	L(check_ret_vec_page_cross)

#  ifdef USE_AS_STRNCMP
	cmpq	$4, %rdx
	jbe	L(ret_zero_page_cross_slow_case1)
#  endif
	movl	$((VEC_SIZE - 4) / SIZE_OF_CHAR), %OFFSET_REG
	subl	%eax, %OFFSET_REG

	vmovd	(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm0
	vmovd	(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %xmm1
	VPTESTM	%xmm0, %xmm0, %k2
	CMP_R1_R2_XMM (%xmm0, %xmm1, %k1){%k2}
	kmovV	%k1, %VRCX
	subl	$0xf, %ecx
	jnz	L(check_ret_vec_page_cross)
#  ifdef USE_AS_STRNCMP
	addl	$(4 / SIZE_OF_CHAR), %OFFSET_REG
	subq	%OFFSET_REG64, %rdx
	jbe	L(ret_zero_page_cross_slow_case1)
	subq	$-(CHAR_PER_VEC * 4), %rdx

	leaq	-(VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	-(VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
#  else
	leaq	(4 - VEC_SIZE * 4)(%rdi, %OFFSET_REG64, SIZE_OF_CHAR), %rdi
	leaq	(4 - VEC_SIZE * 4)(%rsi, %OFFSET_REG64, SIZE_OF_CHAR), %rsi
#  endif
	jmp	L(prepare_loop_aligned)


#  ifdef USE_AS_STRNCMP
	.p2align 4,, 2
L(ret_zero_page_cross_slow_case1):
	xorl	%eax, %eax
	ret
#  endif

	.p2align 4,, 10
L(less_4_till_page):
	subq	%rdi, %rsi
	/* Extremely slow byte comparison loop.  */
L(less_4_loop):
	movzbl	(%rdi), %eax
	movzbl	(%rsi, %rdi), %ecx
	TOLOWER_gpr (%rax, %eax)
	TOLOWER_gpr (%rcx, %BYTE_LOOP_REG)
	subl	%BYTE_LOOP_REG, %eax
	jnz	L(ret_less_4_loop)
	testl	%ecx, %ecx
	jz	L(ret_zero_4_loop)
#  ifdef USE_AS_STRNCMP
	decq	%rdx
	jz	L(ret_zero_4_loop)
#  endif
	incq	%rdi
	/* end condition is reach page boundary (rdi is aligned).  */
	testb	$(VEC_SIZE - 1), %dil
	jnz	L(less_4_loop)
	leaq	-(VEC_SIZE * 4)(%rdi, %rsi), %rsi
	addq	$-(VEC_SIZE * 4), %rdi
#  ifdef USE_AS_STRNCMP
	subq	$-(CHAR_PER_VEC * 4), %rdx
#  endif
	jmp	L(prepare_loop_aligned)

L(ret_zero_4_loop):
	xorl	%eax, %eax
	ret
L(ret_less_4_loop):
	xorl	%r8d, %eax
	subl	%r8d, %eax
	ret
# endif
END(STRCMP)
#endif
