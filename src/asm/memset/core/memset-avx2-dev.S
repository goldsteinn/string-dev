/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if defined(__AVX2__) || 1

# define LABEL(x)	.L##x

	.text
	.p2align 5, 0x90
	.global	MEMSET
	.type	MEMSET, @function
MEMSET:
	.cfi_startproc

	// RDI is the buffer
	// RSI is the value
	// RDX is length
	vmovd	%esi, %xmm0
	vpbroadcastb %xmm0, %ymm0
	mov	%rdi, %rax
	cmp	$0x40, %rdx
	ja	LABEL(above_64)

LABEL(below_64):
	cmp	$0x20, %edx
	jb	LABEL(below_32)
	vmovdqu	%ymm0, (%rdi)
	vmovdqu	%ymm0, -0x20(%rdi, %rdx)
	vzeroupper
	retq

	.align	2
LABEL(in_16_to_32):
	vmovups	%xmm0, (%rdi)
	vmovups	%xmm0, -0x10(%rdi, %rdx)
	vzeroupper
	retq


	.align	32
LABEL(below_32):
	cmp	$0x10, %edx
	jae	LABEL(in_16_to_32)

LABEL(below_16):
	vmovq	%xmm0, %rcx
	vzeroupper
	cmp	$0x4, %edx
	jb	LABEL(below_4)

LABEL(in_4_to_16):
	// Scalar stores from this point.
	cmp	$0x7, %edx
	jbe	LABEL(in_4_to_8)
	// Two 8-wide stores, up to 16 bytes.
	mov	%rcx, -0x8(%rdi, %rdx)
	mov	%rcx, (%rdi)
	retq

	.align	32
LABEL(below_4):
	cmp	$0x1, %edx
	jb	LABEL(exit)
	mov	%sil, (%rdi)
	je	LABEL(exit)
	mov	%cx, -2(%rdi, %rdx)

LABEL(exit):
	retq

	.align	16
LABEL(in_4_to_8):
	// two 4-wide stores, upto 8 bytes.
	mov	%ecx, -0x4(%rdi, %rdx)
	mov	%ecx, (%rdi)
	vzeroupper
	retq

	.align	16
LABEL(above_64):
	cmp	$0xc0, %rdx
	ja	LABEL(above_192)
	vmovdqu	%ymm0, (%rdi)
	vmovdqu	%ymm0, 0x20(%rdi)

	cmp	$0x80, %edx
	jbe	LABEL(in_64_to_128)
	// Do some work filling unaligned 32bit words.
	// last_word -> rsi
	// rcx -> fill pointer.
	// We have at least 128 bytes to store.
	vmovdqu	%ymm0, 0x40(%rdi)
	vmovdqu	%ymm0, 0x60(%rdi)
LABEL(in_64_to_128):
	vmovdqu	%ymm0, -0x40(%rdi, %rdx)
	vmovdqu	%ymm0, -0x20(%rdi, %rdx)
	vzeroupper
	retq

	.align	16
LABEL(above_192):
	// rdi is the buffer address
	// rsi is the value
	// rdx is length
	cmp	$0x1000, %rdx
	jae	LABEL(large_stosq)
	// Store the first unaligned 32 bytes.
	vmovdqu	%ymm0, (%rdi)
	// The first aligned word is stored in %rsi.
	lea	-0xa0(%rdi, %rdx), %rsi
	orq	$0x1f, %rdi
	inc	%rdi
	cmp	%rdi, %rsi
	jb	LABEL(stamp_4)

	.align	16,, 4
LABEL(fill_192):
	vmovdqa	%ymm0, (%rdi)
	vmovdqa	%ymm0, 0x20(%rdi)
	vmovdqa	%ymm0, 0x40(%rdi)
	vmovdqa	%ymm0, 0x60(%rdi)
	vmovdqa	%ymm0, 0x80(%rdi)
	add	$0xa0, %rdi
	cmp	%rdi, %rsi
	ja	LABEL(fill_192)

LABEL(fill_192_tail):
	sub	%rdi, %rsi
	cmp	$-0x80, %esi
	jle	LABEL(fill_192_done)
	vmovdqa	%ymm0, 0x20(%rdi)

	cmp	$-0x60, %esi
	jle	LABEL(fill_192_done)
	vmovdqa	%ymm0, 0x40(%rdi)

	cmp	$-0x40, %esi
	jle	LABEL(fill_192_done)
	vmovdqa	%ymm0, 0x60(%rdi)

	cmp	$-0x20, %edi
	jle	LABEL(fill_192_done)
	vmovdqa	%ymm0, 0x80(%rdi)


LABEL(fill_192_done):
	// Stamp the last word.
	vmovdqu	%ymm0, (%rdi, %rsi)
	vzeroupper
	// FIXME return buffer address
	ret
	.align	16
LABEL(stamp_4):
	vmovdqa	%ymm0, (%rdi)
	vmovdqa	%ymm0, 0x20(%rdi)
	vmovdqa	%ymm0, 0x40(%rdi)
	vmovdqa	%ymm0, 0x60(%rdi)
	vmovdqa	%ymm0, 0x80(%rsi)
	vzeroupper
	ret
	.align	16
LABEL(large_stosq):
	// rdi is the buffer address
	// rsi is the value
	// rdx is length
	vmovq	%xmm0, %rax
	mov	%rax, (%rdi)
	mov	%rdi, %rsi
	// Align rdi to 8B
	and	$0xfffffffffffffff8, %rdi
	add	$8, %rdi
	// Fill buffer using stosq
	lea	-8(%rdx), %rcx
	shrq	$0x3, %rcx
	// rcx - number of QWORD elements
	// rax - value
	// rdi - buffer pointer
	rep	stosq
	// Fill last 16 bytes
	vmovdqu	%xmm0, -0x10(%rsi, %rdx)
	vzeroupper
	mov	%rsi, %rax
	ret

	.cfi_endproc
	.size	MEMSET, .-MEMSET


#endif	// __AVX2__
#ifdef __linux__
	.section .note.GNU-stack, "", @progbits
#endif
