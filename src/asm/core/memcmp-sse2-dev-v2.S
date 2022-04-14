#include "../libc-asm-common.h"

#ifdef USE_AS_WMEMCMP
# define PCMPEQ	pcmpeqd
# define CHAR_SIZE	4
#else /* !USE_AS_WMEMCMP */
# define PCMPEQ	pcmpeqb
# define CHAR_SIZE	1
#endif /* !USE_AS_WMEMCMP */

#define VEC_SIZE	16

ENTRY(MEMCMP)
	cmpq	$(VEC_SIZE / CHAR_SIZE), %rdx
	ja	L(LB17_UBinf)

#ifdef USE_AS_WMEMCMP
	cmpl	$1, %edx
	jbe	L(LB0_UB1)

	movq	(%rsi), %xmm0
	movq	(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	incb	%al
	jnz	L(ret_nonzero_vec_start_0)

	movq	-8(%rsi, %rdx, CHAR_SIZE), %xmm0
	movq	-8(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	incw	%ax
	jnz	L(ret_nonzero_vec_end_0_add8)
#else /* !USE_AS_WMEMCMP */
	cmpl	$8, %edx
	ja	L(LB9_UB16)

	cmpl	$4, %edx
	jb	L(LB0_UB3)


# ifdef USE_AS_MEMCMPEQ
	movl	(%rsi), %eax
	subl	(%rdi), %eax

	movl	-4(%rsi, %rdx), %esi
	subl	-4(%rdi, %rdx), %esi

	orl	%esi, %eax
	ret
# else /* !USE_AS_MEMCMPEQ */
	/* Load registers we need to shift first.  */
	movl	-4(%rsi, %rdx), %ecx
	movl	-4(%rdi, %rdx), %eax
	shlq	$32, %rcx
	shlq	$32, %rax
	movl	(%rsi), %esi
	movl	(%rdi), %edi
	orq	%rsi, %rcx
	orq	%rdi, %rax

	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)
	xorl	%eax, %eax
	ret
# endif /* !USE_AS_MEMCMPEQ */

	// Range       : [9, 16]
	// % Of Calls  : 24.97
	// copy        :
	.p2align 4,, 10
L(LB9_UB16):

# ifdef USE_AS_MEMCMPEQ
	movq	(%rsi), %rax
	subq	(%rdi), %rax

	movq	-8(%rsi, %rdx), %rcx
	subq	-8(%rdi, %rdx), %rcx
	orq	%rcx, %rax
	/* Convert 64 bit -> 32 bit boolean.  */
	setnz	%cl
	movzbl	%cl, %eax
# else /* !USE_AS_MEMCMPEQ */
	movq	(%rsi), %rcx
	movq	(%rdi), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)

	movq	-8(%rsi, %rdx, CHAR_SIZE), %rcx
	movq	-8(%rdi, %rdx, CHAR_SIZE), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)
	xorl	%eax, %eax
# endif /* !USE_AS_MEMCMPEQ */
#endif /* !USE_AS_WMEMCMP */
	ret

	// Range       : [0, 1]
	// % Of Calls  : 1.29
	// branch      : T = 0.01, NT = 99.99
	.p2align 4,, 8
L(LB0_UB1):
	jne	L(LB0_UB0)

	// Range       : [1, 1]
	// % Of Calls  : 1.29
	// copy        :
#ifdef USE_AS_WMEMCMP
	movl	(%rdi), %ecx
	xorl	%edx, %edx
	cmpl	(%rsi), %ecx
	je	L(LB0_UB0)
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#else /* !USE_AS_WMEMCMP */
	movzbl	(%rdi), %eax
	movzbl	(%rsi), %ecx
	subl	%ecx, %eax
#endif /* !USE_AS_WMEMCMP */
	ret

L(LB0_UB0):
	xorl	%eax, %eax
	ret

#ifdef USE_AS_WMEMCMP
	.p2align 4
L(ret_nonzero_vec_start_0):
	bsfl	%eax, %eax
	movl	(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
	ret

#else /* !USE_AS_WMEMCMP */

# ifndef USE_AS_MEMCMPEQ
	.p2align 4,, 14
L(ret_nonzero):
	bswapq	%rcx
	bswapq	%rax
	subq	%rcx, %rax
	sbbl	%eax, %eax
	orl	$1, %eax
	ret
# endif /* !USE_AS_MEMCMPEQ */


	// Range       : [0, 3]
	// % Of Calls  : 10.61
	// branch      : T = 12.18, NT = 87.82
	.p2align 4
L(LB0_UB3):
# ifdef USE_AS_MEMCMPEQ
	/* No reason to add to dependency chain on rdx. Saving a the
	   bytes here doesn't change number of fetch blocks.  */
	cmpl	$1, %edx
	jbe	L(LB0_UB1)
# else /* !USE_AS_MEMCMPEQ */
	/* We need the code size to prevent taking an extra fetch block.
	 */
	decl	%edx
	jle	L(LB0_UB1)
# endif /* !USE_AS_MEMCMPEQ */
	movzwl	(%rsi), %ecx
	movzwl	(%rdi), %eax

# ifdef USE_AS_MEMCMPEQ
	subl	%ecx, %eax

	movzbl	-1(%rsi, %rdx), %esi
	movzbl	-1(%rdi, %rdx), %edi
	subl	%edi, %esi
	orl	%esi, %eax
# else /* !USE_AS_MEMCMPEQ */
	bswapl	%ecx
	bswapl	%eax

	/* Implicit right shift by one. We just need to displace the
	   sign bits.  */
	shrl	%ecx
	shrl	%eax

	/* Eat a partial register stall here. Saves code size. On SnB+
	   this is likely worth it as the merging uop ~= cost of 2x
	   ALU.  */
	movb	(%rsi, %rdx), %cl
	movzbl	(%rdi, %rdx), %edi
	orl	%edi, %eax
	subl	%ecx, %eax
# endif /* !USE_AS_MEMCMPEQ */
	ret
#endif /* !USE_AS_WMEMCMP */


	// Range       : [17, 18446744073709551615]
	// % Of Calls  : 23.02
	// branch      : T = 23.35, NT = 76.65
	.p2align 5
L(LB17_UBinf):
	movups	(%rsi), %xmm0
	movups	(%rdi), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_vec_start_0)

	cmpq	$((VEC_SIZE * 2) / CHAR_SIZE), %rdx
	ja	L(LB33_UBinf_H1_16)

	movups	(VEC_SIZE * -1)(%rsi, %rdx, CHAR_SIZE), %xmm0
	movups	(VEC_SIZE * -1)(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	subl	$0xffff, %eax
#ifndef USE_AS_MEMCMPEQ
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	jnz	L(ret_nonzero_vec_end_0)
#else /* USE_AS_MEMCMPEQ */
L(ret_nonzero_vec_start_0):
L(ret_nonzero_vec_end_0):
L(ret_nonzero_loop):
#endif /* USE_AS_MEMCMPEQ */
	ret

#ifndef USE_AS_MEMCMPEQ
# ifdef USE_AS_WMEMCMP
	.p2align 4
L(ret_nonzero_vec_end_0_add8):
	addl	$2, %edx
# else /* !USE_AS_WMEMCMP */
	.p2align 4,, 8
# endif /* !USE_AS_WMEMCMP */
L(ret_nonzero_vec_end_0):
	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	leal	(%rax, %rdx, CHAR_SIZE), %eax
	movl	(VEC_SIZE * -1)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * -1)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else /* !USE_AS_WMEMCMP */
	addl	%edx, %eax
	movzbl	(VEC_SIZE * -1)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * -1)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif /* !USE_AS_WMEMCMP */
	ret
# ifndef USE_AS_WMEMCMP
	.p2align 4
L(ret_nonzero_vec_start_0):
	bsfl	%eax, %eax
	movzbl	(%rsi, %rax), %ecx
	movzbl	(%rdi, %rax), %eax
	subl	%ecx, %eax
	ret
# endif /* !USE_AS_WMEMCMP */
#endif /* !USE_AS_MEMCMPEQ */



	// Range       : [33, 18446744073709551615]
	// % Of Calls  : 5.37
	// branch      : T = 32.56, NT = 67.44
	.p2align 4
L(LB33_UBinf_H1_16):
	cmpq	$((VEC_SIZE * 4) / CHAR_SIZE), %rdx
	jbe	L(LB33_UB64_H1_16)

	subq	%rdi, %rsi
	leaq	(VEC_SIZE * -4)(%rdi, %rdx, CHAR_SIZE), %rdx
	andq	$(VEC_SIZE * -1), %rdi
	addq	%rdi, %rsi
	subq	%rdi, %rdx
	.p2align 4
L(loop_3x):
	movups	(VEC_SIZE * 1)(%rsi), %xmm0
	movups	(VEC_SIZE * 2)(%rsi), %xmm1
	movups	(VEC_SIZE * 3)(%rsi), %xmm2
	PCMPEQ	(VEC_SIZE * 1)(%rdi), %xmm0
	PCMPEQ	(VEC_SIZE * 2)(%rdi), %xmm1
	PCMPEQ	(VEC_SIZE * 3)(%rdi), %xmm2
	pand	%xmm0, %xmm1
	pand	%xmm1, %xmm2
	pmovmskb %xmm2, %eax
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_loop)
	addq	$(VEC_SIZE * 3), %rdi
	addq	$(VEC_SIZE * 3), %rsi
	subq	$(VEC_SIZE * 3), %rdx
	ja	L(loop_3x)
	addl	$(VEC_SIZE * 4), %edx
#ifdef USE_AS_WMEMCMP
	shrl	$2, %edx
#endif /* USE_AS_WMEMCMP */

	cmpl	$((VEC_SIZE * 3) / CHAR_SIZE), %edx
	jbe	L(last_2x_vec)

	.p2align 4,, 8
L(LB33_UB64_H1_16):
	movups	(VEC_SIZE * 1)(%rsi), %xmm0
	movups	(VEC_SIZE * 1)(%rdi), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_vec_start_1)
	.p2align 4,, 5
L(last_2x_vec):
	movups	(VEC_SIZE * -1)(%rsi, %rdx, CHAR_SIZE), %xmm1
	movups	(VEC_SIZE * -1)(%rdi, %rdx, CHAR_SIZE), %xmm3
	PCMPEQ	%xmm3, %xmm1
	movups	-(VEC_SIZE * 2)(%rsi, %rdx, CHAR_SIZE), %xmm0
	movups	-(VEC_SIZE * 2)(%rdi, %rdx, CHAR_SIZE), %xmm2
	PCMPEQ	%xmm2, %xmm0

	pand	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	subl	$0xffff, %eax
#ifdef USE_AS_MEMCMPEQ
L(ret_nonzero_vec_start_1):
L(ret_nonzero_vec_end_1):
#else /* !USE_AS_MEMCMPEQ */
	jnz	L(ret_nonzero_vec_end_1)
#endif /* !USE_AS_MEMCMPEQ */
	ret

#ifndef USE_AS_MEMCMPEQ
	.p2align 4,, 8
L(ret_nonzero_vec_start_1):
	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 1)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 1)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else /* !USE_AS_WMEMCMP */
	movzbl	(VEC_SIZE * 1)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 1)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif /* !USE_AS_WMEMCMP */
	ret

	/* L(loop_ret_nonzero) and L(loop_tail_end) must be positioned
	   so that jumps from within L(loop_0x0) can get 2-byte
	   encoding. Otherwise the jump table with be incorrect.  */
	.p2align 4
L(ret_nonzero_loop):
	pmovmskb %xmm1, %edx
	pmovmskb %xmm0, %ecx
	sall	$(VEC_SIZE * 1), %edx
	salq	$(VEC_SIZE * 2), %rax
	leal	1(%rcx, %rdx), %edx
	orq	%rdx, %rax
	bsfq	%rax, %rax
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 1)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 1)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else /* !USE_AS_WMEMCMP */
	movzbl	(VEC_SIZE * 1)(%rsi, %rax), %ecx
	movb	(VEC_SIZE * 1)(%rdi, %rax), %al
	subl	%ecx, %eax
# endif /* !USE_AS_WMEMCMP */
	ret

	.p2align 4,, 8
L(ret_nonzero_vec_end_1):
	pmovmskb %xmm0, %ecx
	rorl	$16, %eax
	xorl	%ecx, %eax
	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	leal	(%rax, %rdx, CHAR_SIZE), %eax
	movl	(VEC_SIZE * -2)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * -2)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else /* !USE_AS_WMEMCMP */
	addl	%edx, %eax
	movzbl	(VEC_SIZE * -2)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * -2)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif /* !USE_AS_WMEMCMP */
	ret

#endif /* !USE_AS_MEMCMPEQ */

END(MEMCMP)
