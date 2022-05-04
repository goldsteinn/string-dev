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


#include "../../libc-asm-common.h"

#define PAGE_SIZE	4096
#define VEC_SIZE	16
	.text
ENTRY(STRRCHR)
	movd	%esi, %xmm0
	movq	%rdi, %rax
	andl	$(PAGE_SIZE - 1), %eax
	punpcklbw %xmm0, %xmm0
	punpcklwd %xmm0, %xmm0
	pshufd	$0, %xmm0, %xmm0
	cmpq	$(PAGE_SIZE - VEC_SIZE * 4), %rax
	ja	L(cross_page)
	movups	(%rdi), %xmm1
	/* At least as cheap or cheaper to refresh zero vs copy load.
	 */
	pxor	%xmm2, %xmm2
	pcmpeqb	%xmm1, %xmm2
	pcmpeqb	%xmm0, %xmm1

	pmovmskb %xmm1, %ecx
	pmovmskb %xmm2, %edx

	testl	%edx, %edx
	je	L(next_48_bytes)
	leal	-1(%edx), %eax
	xorl	%edx, %eax
	andl	%ecx, %eax
	je	L(exit0)
	bsrl	%eax, %eax
	addq	%rdi, %rax
L(exit0):
	ret

	.p2align 4
L(next_48_bytes):
	movups	(VEC_SIZE * 1)(%rdi), %xmm1
	movups	(VEC_SIZE * 2)(%rdi), %xmm2
	movups	(VEC_SIZE * 3)(%rdi), %xmm3

	pxor	%xmm4, %xmm4
	pcmpeqb	%xmm1, %xmm4
	pcmpeqb	%xmm0, %xmm1

	pxor	%xmm5, %xmm5
	pcmpeqb	%xmm2, %xmm5
	pcmpeqb	%xmm0, %xmm2

	pxor	%xmm6, %xmm6
	pcmpeqb	%xmm3, %xmm6
	pcmpeqb	%xmm0, %xmm3

	pmovmskb %xmm4, %edx
	pmovmskb %xmm1, %esi

	sall	$16, %edx
	sall	$16, %esi

	/* Include result from first comparison with CHAR.  */
	orl	%ecx, %esi

	pmovmskb %xmm5, %eax
	pmovmskb %xmm2, %ecx

	salq	$32, %rax
	salq	$32, %rcx

	orq	%rax, %rdx
	orq	%rcx, %rsi

	pmovmskb %xmm3, %rcx
	pmovmskb %xmm6, %eax

	salq	$48, %rcx
	salq	$48, %rax

	orq	%rcx, %rsi

	/* Use add for micro-fusion.  */
	addq	%rax, %rdx
	je	L(loop_header2)
	leaq	-1(%rdx), %rax
	xorq	%rdx, %rax
	andq	%rsi, %rax
	je	L(exit1)
	bsrq	%rax, %rax
	addq	%rdi, %rax
L(exit1):
	ret


	.p2align 4
L(no_c_found):
	movl	$1, %esi
	xorl	%ecx, %ecx
	jmp	L(loop_header)

	.p2align 4
L(loop_header2):
	movq	%rdi, %rcx
	testq	%rsi, %rsi
	je	L(no_c_found)
L(loop_header):
	orq	$(VEC_SIZE * 4 - 1), %rdi
	pxor	%xmm7, %xmm7
	incq	%rdi
	jmp	L(loop_entry)

	.p2align 4
L(loop64):
	testq	%rdx, %rdx
	cmovne	%rdx, %rsi
	cmovne	%rdi, %rcx
	addq	$64, %rdi
L(loop_entry):
	movaps	(VEC_SIZE * 0)(%rdi), %xmm1
	movaps	(VEC_SIZE * 1)(%rdi), %xmm2
	movaps	(VEC_SIZE * 2)(%rdi), %xmm3
	movaps	(VEC_SIZE * 3)(%rdi), %xmm4

	movaps	%xmm1, %xmm5
	pcmpeqb	%xmm0, %xmm5

	movaps	%xmm2, %xmm6
	pcmpeqb	%xmm0, %xmm6

	pmovmskb %xmm5, %eax
	pmovmskb %xmm6, %edx

	sall	$16, %edx
	orl	%eax, %edx

	movaps	%xmm3, %xmm5
	pcmpeqb	%xmm0, %xmm5

	movaps	%xmm4, %xmm6
	pcmpeqb	%xmm0, %xmm6

	pmovmskb %xmm5, %eax
	salq	$32, %rax
	pmovmskb %xmm6, %r8d
	salq	$48, %r8
	orq	%r8, %rax
	orq	%rax, %rdx

	pminub	%xmm1, %xmm2
	pminub	%xmm3, %xmm4
	pminub	%xmm2, %xmm4

	pcmpeqb	%xmm7, %xmm4
	pmovmskb %xmm4, %eax
	testl	%eax, %eax
	je	L(loop64)

	pcmpeqb	%xmm7, %xmm1
	pcmpeqb	%xmm7, %xmm2
	pcmpeqb	%xmm7, %xmm3

	vpmovmskb %xmm1, %r8d
	vpmovmskb %xmm2, %r9d
	vpmovmskb %xmm3, %r10d

	sall	$16, %r9d
	salq	$32, %r10
	salq	$48, %rax

	orl	%r8d, %r9d
	orq	%r10, %rax

	orq	%r9, %rax

	leaq	-1(%rax), %r8
	xorq	%r8, %rax
	andq	%rdx, %rax
	cmovne	%rdi, %rcx
	cmove	%rsi, %rax
	bsrq	%rax, %rax
	addq	%rcx, %rax
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
	pcmpeqb	%xmm1, %xmm5
	pcmpeqb	%xmm0, %xmm1

	pxor	%xmm6, %xmm6
	pcmpeqb	%xmm2, %xmm6
	pcmpeqb	%xmm0, %xmm2

	pmovmskb %xmm5, %eax
	pmovmskb %xmm1, %ecx

	pmovmskb %xmm6, %edx
	pmovmskb %xmm2, %esi

	sall	$16, %edx
	sall	$16, %esi

	orl	%eax, %edx
	orl	%ecx, %esi

	pxor	%xmm5, %xmm5
	pcmpeqb	%xmm3, %xmm5
	pcmpeqb	%xmm0, %xmm3

	pxor	%xmm6, %xmm6
	pcmpeqb	%xmm4, %xmm6
	pcmpeqb	%xmm0, %xmm4

	pmovmskb %xmm5, %eax
	pmovmskb %xmm3, %ecx

	salq	$32, %rax
	salq	$32, %rcx

	orq	%rax, %rdx
	orq	%rcx, %rsi

	pmovmskb %xmm4, %ecx
	pmovmskb %xmm6, %eax

	salq	$48, %rcx
	salq	$48, %rax

	orq	%rcx, %rsi
	orq	%rax, %rdx
	movl	%edi, %ecx
	shrq	%cl, %rsi
	shrq	%cl, %rdx
	jz	L(loop_header2)
	leaq	-1(%rdx), %rax
	xorq	%rdx, %rax
	andq	%rsi, %rax
	je	L(exit2)
	bsrq	%rax, %rax
	addq	%rdi, %rax
L(exit2):
	ret
END(STRRCHR)
