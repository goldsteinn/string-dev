/* strrchr (str, ch) -- Return pointer to last occurrence of CH in STR.
   Copyright (C) 2013-2022 Free Software Foundation, Inc.
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
	cmpq	$(PAGE_SIZE - VEC_SIZE * 4), %rax
	ja	L(cross_page)

L(page_cross_continue):
	movups	(%rdi), %xmm1
	/* At least as cheap or cheaper to refresh zero vs copy load.
	 */
	pxor	%xmm2, %xmm2
	PCMPEQ	%xmm1, %xmm2
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm2, %edx

	testl	%edx, %edx
	je	L(next_48_bytes)

	pmovmskb %xmm1, %ecx

	leal	-1(%edx), %eax
	xorl	%edx, %eax
	andl	%ecx, %eax
	je	L(exit0)
	bsrl	%eax, %eax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
L(exit0):
	ret

	.p2align 4
L(next_48_bytes):
	movups	(VEC_SIZE * 1)(%rdi), %xmm2
	movups	(VEC_SIZE * 2)(%rdi), %xmm3
	movups	(VEC_SIZE * 3)(%rdi), %xmm4

	pxor	%xmm5, %xmm5
	PCMPEQ	%xmm2, %xmm5

	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm3, %xmm6

	pxor	%xmm7, %xmm7
	PCMPEQ	%xmm4, %xmm7

	pmovmskb %xmm5, %edx
	pmovmskb %xmm6, %esi
	pmovmskb %xmm7, %ecx

	sall	$16, %edx

	sall	$16, %ecx
	addl	%ecx, %esi
	salq	$32, %rsi

	PCMPEQ	%xmm0, %xmm2
	PCMPEQ	%xmm0, %xmm3
	PCMPEQ	%xmm0, %xmm4

	/* Use add for micro-fusion.  */
	addq	%rdx, %rsi
	je	L(loop_header)

	pmovmskb %xmm1, %edx
	pmovmskb %xmm2, %eax

	sall	$16, %eax
	addl	%edx, %eax

	pmovmskb %xmm3, %ecx
	pmovmskb %xmm4, %edx

	sall	$16, %edx
	addl	%ecx, %edx

	salq	$32, %rdx

	addq	%rdx, %rax

	leaq	-1(%rsi), %rdx
	xorq	%rdx, %rsi
	andq	%rsi, %rax
	je	L(exit1)
	bsrq	%rax, %rax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
L(exit1):
	ret

L(loop_header):
	pxor	%xmm7, %xmm7
	.p2align 4
L(loop_set_furthest):
	movq	%rdi, %rcx
	andq	$-(VEC_SIZE * 4), %rdi
	movaps	%xmm1, %xmm8
	movaps	%xmm2, %xmm9
	movaps	%xmm3, %xmm10
	movaps	%xmm4, %xmm11
L(loop_entry):
#ifdef USE_AS_WCSRCHR
	movaps	(VEC_SIZE * 4)(%rdi), %xmm1
	movaps	(VEC_SIZE * 5)(%rdi), %xmm2
	movaps	(VEC_SIZE * 6)(%rdi), %xmm3
	movaps	(VEC_SIZE * 7)(%rdi), %xmm4


	pxor	%xmm12, %xmm12
	PCMPEQ	%xmm1, %xmm12

	pxor	%xmm5, %xmm5
	PCMPEQ	%xmm2, %xmm5

	pxor	%xmm13, %xmm13
	PCMPEQ	%xmm3, %xmm13

	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm4, %xmm6

	por	%xmm12, %xmm5
	por	%xmm13, %xmm6
	por	%xmm5, %xmm6

	PCMPEQ	%xmm0, %xmm1
	PCMPEQ	%xmm0, %xmm2

	PCMPEQ	%xmm0, %xmm3
	PCMPEQ	%xmm0, %xmm4
#else
	movaps	(VEC_SIZE * 4)(%rdi), %xmm1
	movaps	(VEC_SIZE * 5)(%rdi), %xmm5
	movaps	(VEC_SIZE * 6)(%rdi), %xmm3
	movaps	(VEC_SIZE * 7)(%rdi), %xmm6


	movaps	%xmm5, %xmm2
	pminub	%xmm1, %xmm5
	movaps	%xmm6, %xmm4
	pminub	%xmm3, %xmm6
	pminub	%xmm5, %xmm6

	/* NB: We reduce with pcmpeq + por instead of pxor + pmin. This
	   allows us to feed the output of L(next_48_bytes) into this
	   start of this loop and allows us to compute a seperate mask
	   for zero matches. If the input is expected to be long an
	   contain no search CHARs until the end this the pxor + pmin
	   version will be faster.  */
	movaps	%xmm1, %xmm12
	PCMPEQ	%xmm0, %xmm1
	PCMPEQ	%xmm0, %xmm2

	movaps	%xmm3, %xmm13
	PCMPEQ	%xmm0, %xmm3
	PCMPEQ	%xmm0, %xmm4

	PCMPEQ	%xmm7, %xmm6
#endif
	movaps	%xmm2, %xmm14
	por	%xmm1, %xmm14
	movaps	%xmm4, %xmm15
	por	%xmm3, %xmm15

	por	%xmm14, %xmm15
	pmovmskb %xmm15, %edx
	pmovmskb %xmm6, %eax

	addq	$(VEC_SIZE * 4), %rdi
	addl	%eax, %edx
	je	L(loop_entry)

	testl	%eax, %eax
	jz	L(loop_set_furthest)

	cmpl	%eax, %edx
	jne	L(last_char_in_loop)
L(last_char_out_of_bounds):
	vpmovmskb %xmm8, %edi
	vpmovmskb %xmm9, %edx
	vpmovmskb %xmm10, %esi
	vpmovmskb %xmm11, %eax

	sall	$16, %edx
	sall	$16, %eax

	orl	%edi, %edx
	orl	%esi, %eax
	salq	$32, %rax
	orq	%rdx, %rax

	bsrq	%rax, %rax
	leaq	-(CHAR_SIZE - 1)(%rcx, %rax), %rcx
	cmovnz	%rcx, %rax
	ret

	.p2align 4,, 8
L(last_char_in_loop):
	vpmovmskb %xmm1, %edx
	vpmovmskb %xmm2, %esi
	vpmovmskb %xmm3, %r8
	vpmovmskb %xmm4, %r9

	sall	$16, %esi
	orl	%esi, %edx

	salq	$32, %r8
	salq	$48, %r9

	orq	%r8, %r9
	orq	%rdx, %r9
#ifndef USE_AS_WCSRCHR
	PCMPEQ	%xmm7, %xmm12
	PCMPEQ	%xmm7, %xmm5
	PCMPEQ	%xmm7, %xmm13
#endif
	vpmovmskb %xmm12, %edx
	vpmovmskb %xmm5, %esi
	vpmovmskb %xmm13, %r8d

	sall	$16, %esi
	orl	%edx, %esi

	sall	$16, %eax
	orl	%r8d, %eax

	salq	$32, %rax
	orq	%rsi, %rax

	leaq	-1(%rax), %rsi
	xorq	%rsi, %rax
	andq	%r9, %rax
	jz	L(last_char_out_of_bounds)
	bsrq	%rax, %rax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
	ret

	.p2align 4
L(cross_page):
	movq	%rdi, %rax
	andq	$-(VEC_SIZE * 4), %rax

	movups	(VEC_SIZE * 0)(%rax), %xmm1
	movups	(VEC_SIZE * 1)(%rax), %xmm2
	movups	(VEC_SIZE * 2)(%rax), %xmm3
	movups	(VEC_SIZE * 3)(%rax), %xmm4

	pxor	%xmm5, %xmm5
	PCMPEQ	%xmm1, %xmm5

	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm2, %xmm6

	pmovmskb %xmm5, %ecx
	pmovmskb %xmm6, %edx

	pxor	%xmm5, %xmm5
	PCMPEQ	%xmm3, %xmm5

	pxor	%xmm6, %xmm6
	PCMPEQ	%xmm4, %xmm6

	pmovmskb %xmm5, %esi
	pmovmskb %xmm6, %eax

	sall	$16, %edx
	sall	$16, %eax
	orl	%ecx, %edx
	orl	%esi, %eax
	salq	$32, %rax
	orq	%rdx, %rax

	movl	%edi, %ecx

	shrq	%cl, %rax
	jz	L(page_cross_continue)

	PCMPEQ	%xmm0, %xmm1
	PCMPEQ	%xmm0, %xmm2
	PCMPEQ	%xmm0, %xmm3
	PCMPEQ	%xmm0, %xmm4

	pmovmskb %xmm1, %edx
	pmovmskb %xmm2, %esi

	pmovmskb %xmm3, %r8
	pmovmskb %xmm4, %r9

	sall	$16, %esi
	orl	%edx, %esi

	salq	$32, %r8
	salq	$48, %r9

	orq	%r8, %r9
	orq	%rsi, %r9

	shrq	%cl, %r9

	leaq	-1(%rax), %rdx
	xorq	%rdx, %rax


	andq	%r9, %rax
	je	L(exit2)
	bsrq	%rax, %rax
#ifdef USE_AS_WCSRCHR
	leaq	-(CHAR_SIZE - 1)(%rdi, %rax), %rax
#else
	addq	%rdi, %rax
#endif
L(exit2):
	ret
END(STRRCHR)
