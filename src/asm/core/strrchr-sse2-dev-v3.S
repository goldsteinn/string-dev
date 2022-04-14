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

#include "../libc-asm-common.h"

#ifdef USE_AS_WCSRCHR
# define PCMPEQ	pcmpeqd
# define CHAR_SIZE	4
#else
# define PCMPEQ	pcmpeqb
# define CHAR_SIZE	1
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
L(aligned_more):
	movq	%rdi, %r8
	andq	$-VEC_SIZE, %rdi

	movaps	VEC_SIZE(%rdi), %xmm3
	pxor	%xmm4, %xmm4
	PCMPEQ	%xmm3, %xmm4
	PCMPEQ	%xmm0, %xmm3
	pmovmskb %xmm4, %ecx
	pmovmskb %xmm3, %eax
	testl	%ecx, %ecx
	jnz	L(first_vec_x1)

	.p2align 4
L(loop_set_match):
	movq	%rdi, %rsi
	movl	%eax, %edx
L(loop):
	movaps	(VEC_SIZE * 2)(%rdi), %xmm3
	pxor	%xmm4, %xmm4
	PCMPEQ	%xmm3, %xmm4
	PCMPEQ	%xmm0, %xmm3

	pmovmskb %xmm4, %ecx
	pmovmskb %xmm3, %eax

	addq	$VEC_SIZE, %rdi
	addl	%eax, %ecx
	jz	L(loop)

	subl	%eax, %ecx
	jz	L(loop_set_match)

	testl	%eax, %eax
	jnz	L(new_match)

L(old_match):
	testl	%edx, %edx
	jz	L(first_vec_x0_test)
	bsrl	%edx, %edx
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 1 -(CHAR_SIZE - 1))(%rsi, %rdx), %rax
#else
	leaq	(VEC_SIZE * 1)(%rsi, %rdx), %rax
#endif
	ret

	.p2align 4
L(new_match):
	leal	-1(%rcx), %r9d
	xorl	%r9d, %ecx
	andl	%ecx, %eax
	jz	L(old_match)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	(VEC_SIZE * 2-(CHAR_SIZE - 1))(%rdi, %rax), %rax
#else
	leaq	(VEC_SIZE * 2)(%rsi, %rax), %rax
#endif
	ret

L(cross_page):
	ret
END(STRRCHR)
