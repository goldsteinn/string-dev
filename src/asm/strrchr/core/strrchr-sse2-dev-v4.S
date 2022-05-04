/* wcsrchr with SSSE3
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

#ifdef USE_AS_WCSRCHR
# define PCMPEQ	pcmpeqd
# define CHAR_SIZE	4
# define PMINU	pminud

#else
# define PCMPEQ	pcmpeqb
# define CHAR_SIZE	1
# define PMINU	pminub
#endif

#define PAGE_SIZE	4096
#define VEC_SIZE	16


	.text
ENTRY(STRRCHR)
	movd	%esi, %xmm0
	movq	%rdi, %rax
	andl	$(PAGE_SIZE - 1), %eax
#ifndef USE_AS_WCSRCHR
	punpcklbw %xmm0, %xmm0
	punpcklwd %xmm0, %xmm0
#endif
	pshufd	$0, %xmm0, %xmm0
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(cross_page)

L(cross_page_continue):
	movups	(%rdi), %xmm1
	pxor	%xmm2, %xmm2
	PCMPEQ	%xmm1, %xmm2
	pmovmskb %xmm2, %ecx
	testl	%ecx, %ecx
	jz	L(aligned_more)

	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	leal	-1(%rcx), %edx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(exit0)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
L(exit0):
	ret

	.p2align 4
L(first_vec_x0_test):
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	testl	%eax, %eax
	jz	L(exit0)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%r8, %rax), %rax
#else
	addq	%r8, %rax
#endif
	ret

	.p2align 4
L(first_vec_x1):
	PCMPEQ	%xmm0, %xmm2
	pmovmskb %xmm2, %eax
	leal	-1(%rcx), %edx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x0_test)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE -(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	leaq	(VEC_SIZE)(%rdi, %rax), %rax
#endif
	ret

	.p2align 4
L(first_vec_x1_test):
	PCMPEQ	%xmm0, %xmm2
	pmovmskb %xmm2, %eax
	testl	%eax, %eax
	jz	L(first_vec_x0_test)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE -(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	leaq	(VEC_SIZE)(%rdi, %rax), %rax
#endif
	ret

	.p2align 4
L(first_vec_x2):
	PCMPEQ	%xmm0, %xmm3
	pmovmskb %xmm3, %eax
	leal	-1(%rcx), %edx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(first_vec_x1_test)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 2-(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	leaq	(VEC_SIZE * 2)(%rdi, %rax), %rax
#endif
	ret

	.p2align 4
L(aligned_more):
	movq	%rdi, %r8
	andq	$-VEC_SIZE, %rdi

	movaps	VEC_SIZE(%rdi), %xmm2
	pxor	%xmm3, %xmm3
	PCMPEQ	%xmm2, %xmm3
	pmovmskb %xmm3, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x1)

	movaps	(VEC_SIZE * 2)(%rdi), %xmm3
	pxor	%xmm4, %xmm4
	PCMPEQ	%xmm3, %xmm4
	pmovmskb %xmm4, %ecx
	testl	%ecx, %ecx
	jnz	L(first_vec_x2)

	addq	$VEC_SIZE, %rdi
	movq	%rdi, %rsi
	andq	$-(VEC_SIZE * 2), %rdi
	.p2align 4
L(first_loop):
	movaps	(VEC_SIZE * 2)(%rdi), %xmm4
	movaps	(VEC_SIZE * 3)(%rdi), %xmm5
#ifdef NO_PMINU
	movaps	%xmm5, %xmm6
	pxor	%xmm8, %xmm8

	PCMPEQ	%xmm8, %xmm5
	PCMPEQ	%xmm4, %xmm8
	por	%xmm5, %xmm8
#else
	movaps	%xmm5, %xmm6
	PMINU	%xmm4, %xmm5
#endif

	movaps	%xmm4, %xmm9
	PCMPEQ	%xmm0, %xmm4
	PCMPEQ	%xmm0, %xmm6
	movaps	%xmm6, %xmm7
	por	%xmm4, %xmm6
#ifndef NO_PMINU
	pxor	%xmm8, %xmm8
	PCMPEQ	%xmm5, %xmm8
#endif
	pmovmskb %xmm8, %ecx
	pmovmskb %xmm6, %eax

	addq	$(VEC_SIZE * 2), %rdi
	addl	%eax, %ecx
	jz	L(first_loop)

	subl	%eax, %ecx
	jz	L(second_loop_match)

	testl	%eax, %eax
	jnz	L(new_match)

L(first_loop_old_match):
	PCMPEQ	%xmm0, %xmm2
	PCMPEQ	%xmm0, %xmm3
	pmovmskb %xmm2, %ecx
	pmovmskb %xmm3, %eax
	addl	%eax, %ecx
	jz	L(first_vec_x0_test)
	sall	$16, %eax
	orl	%ecx, %eax

	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(-(CHAR_SIZE - 1))(%rsi, %rax), %rax
#else
	addq	%rsi, %rax
#endif
	ret

	.p2align 4
L(new_match):
	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm9, %xmm6
	pmovmskb %xmm6, %eax
	sall	$16, %ecx
	orl	%eax, %ecx

	/* We can't reuse either of the old comparisons as since we mask
	   of zeros after first zero (instead of using the full
	   comparison) we can't gurantee no interference between match
	   after end of string and valid match.  */
	pmovmskb %xmm4, %eax
	pmovmskb %xmm7, %edx
	sall	$16, %edx
	orl	%edx, %eax

	leal	-1(%ecx), %edx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(first_loop_old_match)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 0 -(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
	ret

	.p2align 4
L(second_loop_match):
	movq	%rdi, %rsi
	movaps	%xmm4, %xmm2
	movaps	%xmm7, %xmm3

	.p2align 4
L(second_loop):
	movaps	(VEC_SIZE * 2)(%rdi), %xmm4
	movaps	(VEC_SIZE * 3)(%rdi), %xmm5
#ifdef NO_PMINU
	movaps	%xmm5, %xmm6
	pxor	%xmm8, %xmm8

	PCMPEQ	%xmm8, %xmm5
	PCMPEQ	%xmm4, %xmm8
	por	%xmm5, %xmm8
#else
	movaps	%xmm5, %xmm6
	PMINU	%xmm4, %xmm5
#endif

	movaps	%xmm4, %xmm9
	PCMPEQ	%xmm0, %xmm4
	PCMPEQ	%xmm0, %xmm6
	movaps	%xmm6, %xmm7
	por	%xmm4, %xmm6
#ifndef NO_PMINU
	pxor	%xmm8, %xmm8
	PCMPEQ	%xmm5, %xmm8
#endif

	pmovmskb %xmm8, %ecx
	pmovmskb %xmm6, %eax

	addq	$(VEC_SIZE * 2), %rdi
	/* Either null term or new occurence of CHAR.  */
	addl	%ecx, %eax
	jz	L(second_loop)

	/* No null term so much be new occurence of CHAR.  */
	testl	%ecx, %ecx
	jz	L(second_loop_match)


	subl	%ecx, %eax
	jnz	L(second_loop_new_match)

L(second_loop_old_match):
	pmovmskb %xmm2, %ecx
	pmovmskb %xmm3, %eax
	sall	$16, %eax
	orl	%ecx, %eax
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 0-(CHAR_SIZE - 1))(%rsi, %rax), %rax
#else
	addq	%rsi, %rax
#endif
	ret

	.p2align 4
L(second_loop_new_match):
	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm9, %xmm6
	pmovmskb %xmm6, %eax
	sall	$16, %ecx
	orl	%eax, %ecx

	/* We can't reuse either of the old comparisons as since we mask
	   of zeros after first zero (instead of using the full
	   comparison) we can't gurantee no interference between match
	   after end of string and valid match.  */
	pmovmskb %xmm4, %eax
	pmovmskb %xmm7, %edx
	sall	$16, %edx
	orl	%edx, %eax

	leal	-1(%ecx), %edx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(second_loop_old_match)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 0-(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
	ret



L(cross_page):
	movq	%rdi, %rsi
	andq	$-VEC_SIZE, %rsi
	movaps	(%rsi), %xmm1
	pxor	%xmm2, %xmm2
	PCMPEQ	%xmm1, %xmm2
	pmovmskb %xmm2, %edx
	movl	%edi, %ecx
	andl	$(VEC_SIZE - 1), %ecx
	sarl	%cl, %edx
	jz	L(cross_page_continue)
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	sarl	%cl, %eax
	leal	-1(%rdx), %ecx
	xorl	%edx, %ecx
	andl	%ecx, %eax
	jz	L(exit1)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
L(exit1):
	ret
END(STRRCHR)
