#include "../libc-asm-common.h"

#ifdef USE_AS_WMEMCMP
# define PCMPEQ	pcmpeqd
# define CHAR_SIZE	4
# define SIZE_OFFSET	(0)
#else	/* !USE_AS_WMEMCMP */
# define PCMPEQ	pcmpeqb
# define CHAR_SIZE	1
#endif	/* !USE_AS_WMEMCMP */

#ifdef USE_AS_MEMCMPEQ
# define SIZE_OFFSET	(0)
# define CHECK_CMP(x, y)	subl x, y
#else	/* !USE_AS_MEMCMPEQ */
# ifndef SIZE_OFFSET
#  define SIZE_OFFSET	(CHAR_PER_VEC * 2)
# endif	/* !SIZE_OFFSET */
# define CHECK_CMP(x, y)	cmpl x, y
#endif	/* !USE_AS_MEMCMPEQ */

#define VEC_SIZE	16
#define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)


ENTRY(MEMCMP)
#ifdef USE_AS_WMEMCMP
	movl	$0xffff, %ecx
#endif	/* USE_AS_WMEMCMP */
	cmpq	$CHAR_PER_VEC, %rdx
	ja	L(more_1x_vec)

#ifdef USE_AS_WMEMCMP
	decl	%edx
	jle	L(cmp_0_1)

	movq	(%rsi), %xmm0
	movq	(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	subl	%ecx, %eax
	jnz	L(ret_nonzero_vec_start_0)

	movq	-4(%rsi, %rdx, CHAR_SIZE), %xmm0
	movq	-4(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	subl	%ecx, %eax
	jnz	L(ret_nonzero_vec_end_0_add8)
#else	/* !USE_AS_WMEMCMP */
	cmpl	$8, %edx
	ja	L(cmp_9_16)

	cmpl	$4, %edx
	jb	L(cmp_0_3)


# ifdef USE_AS_MEMCMPEQ
	movl	(%rsi), %eax
	subl	(%rdi), %eax

	movl	-4(%rsi, %rdx), %esi
	subl	-4(%rdi, %rdx), %esi

	orl	%esi, %eax
	ret
# else	/* !USE_AS_MEMCMPEQ */
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
# endif	/* !USE_AS_MEMCMPEQ */

	.p2align 4,, 10
L(cmp_9_16):

# ifdef USE_AS_MEMCMPEQ
	movq	(%rsi), %rax
	subq	(%rdi), %rax

	movq	-8(%rsi, %rdx), %rcx
	subq	-8(%rdi, %rdx), %rcx
	orq	%rcx, %rax
	/* Convert 64 bit -> 32 bit boolean.  */
	setnz	%cl
	movzbl	%cl, %eax
# else	/* !USE_AS_MEMCMPEQ */
	movq	(%rsi), %rcx
	movq	(%rdi), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)

	movq	-8(%rsi, %rdx, CHAR_SIZE), %rcx
	movq	-8(%rdi, %rdx, CHAR_SIZE), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)
	xorl	%eax, %eax
# endif	/* !USE_AS_MEMCMPEQ */
#endif	/* !USE_AS_WMEMCMP */
	ret

	.p2align 4,, 8
L(cmp_0_1):
	jne	L(cmp_0_0)
#ifdef USE_AS_WMEMCMP
	movl	(%rdi), %ecx
	xorl	%edx, %edx
	cmpl	(%rsi), %ecx
	je	L(cmp_0_0)
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#else	/* !USE_AS_WMEMCMP */
	movzbl	(%rdi), %eax
	movzbl	(%rsi), %ecx
	subl	%ecx, %eax
#endif	/* !USE_AS_WMEMCMP */
	ret

L(cmp_0_0):
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

#else	/* !USE_AS_WMEMCMP */

# ifndef USE_AS_MEMCMPEQ
	.p2align 4,, 14
L(ret_nonzero):
	bswapq	%rcx
	bswapq	%rax
	subq	%rcx, %rax
	sbbl	%eax, %eax
	orl	$1, %eax
	ret
# endif	/* !USE_AS_MEMCMPEQ */

	.p2align 4
L(cmp_0_3):
# ifdef USE_AS_MEMCMPEQ
	/* No reason to add to dependency chain on rdx. Saving a the
	   bytes here doesn't change number of fetch blocks.  */
	cmpl	$1, %edx
	jbe	L(cmp_0_1)
# else	/* !USE_AS_MEMCMPEQ */
	/* We need the code size to prevent taking an extra fetch block.
	 */
	decl	%edx
	jle	L(cmp_0_1)
# endif	/* !USE_AS_MEMCMPEQ */
	movzwl	(%rsi), %ecx
	movzwl	(%rdi), %eax

# ifdef USE_AS_MEMCMPEQ
	subl	%ecx, %eax

	movzbl	-1(%rsi, %rdx), %esi
	movzbl	-1(%rdi, %rdx), %edi
	subl	%edi, %esi
	orl	%esi, %eax
# else	/* !USE_AS_MEMCMPEQ */
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
# endif	/* !USE_AS_MEMCMPEQ */
	ret
#endif	/* !USE_AS_WMEMCMP */

	.p2align 5
L(more_1x_vec):
#ifndef USE_AS_WMEMCMP
	movl	$0xffff, %ecx
#endif	/* !USE_AS_WMEMCMP */
	movups	(%rsi), %xmm0
	movups	(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	subl	%ecx, %eax
	jnz	L(ret_nonzero_vec_start_0)

#if SIZE_OFFSET == 0
	cmpq	$(CHAR_PER_VEC * 2), %rdx
#else	/* !SIZE_OFFSET == 0 */
	subq	$(CHAR_PER_VEC * 2), %rdx
#endif	/* !SIZE_OFFSET == 0 */
	ja	L(more_2x_vec)

	movups	(VEC_SIZE * -1 + SIZE_OFFSET)(%rsi, %rdx, CHAR_SIZE), %xmm0
	movups	(VEC_SIZE * -1 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	subl	%ecx, %eax
#ifndef USE_AS_MEMCMPEQ
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	jnz	L(ret_nonzero_vec_end_0)
#else	/* USE_AS_MEMCMPEQ */
L(ret_nonzero_vec_start_1):
L(ret_nonzero_vec_start_0):
L(ret_nonzero_vec_end_0):
#endif	/* USE_AS_MEMCMPEQ */
	ret


#ifndef USE_AS_MEMCMPEQ
# ifdef USE_AS_WMEMCMP
	.p2align 4
L(ret_nonzero_vec_end_0_add8):
	addl	$3, %edx
# else	/* !USE_AS_WMEMCMP */
	.p2align 4,, 8
# endif	/* !USE_AS_WMEMCMP */
L(ret_nonzero_vec_end_0):
	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	leal	(%rax, %rdx, CHAR_SIZE), %eax
	movl	(VEC_SIZE * -1 + SIZE_OFFSET)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * -1 + SIZE_OFFSET)(%rsi, %rax), %ecx

	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else	/* !USE_AS_WMEMCMP */
	addl	%edx, %eax
	movzbl	(VEC_SIZE * -1 + SIZE_OFFSET)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * -1 + SIZE_OFFSET)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret
# ifndef USE_AS_WMEMCMP
	.p2align 4,, 10
L(ret_nonzero_vec_start_0):
	bsfl	%eax, %eax
	movzbl	(%rsi, %rax), %ecx
	movzbl	(%rdi, %rax), %eax
	subl	%ecx, %eax
	ret
# endif	/* !USE_AS_WMEMCMP */

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
# else	/* !USE_AS_WMEMCMP */
	movzbl	(VEC_SIZE * 1)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 1)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret
#endif	/* !USE_AS_MEMCMPEQ */

	.p2align 4
L(more_2x_vec):
	movups	(VEC_SIZE * 1)(%rsi), %xmm0
	movups	(VEC_SIZE * 1)(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	pmovmskb %xmm1, %eax
	subl	%ecx, %eax
	jnz	L(ret_nonzero_vec_start_1)

	cmpq	$(CHAR_PER_VEC * 4 - SIZE_OFFSET), %rdx
	jbe	L(last_2x_vec)


	cmpq	$(CHAR_PER_VEC * 8 - SIZE_OFFSET), %rdx
	ja	L(more_8x_vec)


	movups	(VEC_SIZE * 2)(%rsi), %xmm0
	movups	(VEC_SIZE * 2)(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	movups	(VEC_SIZE * 3)(%rsi), %xmm2
	movups	(VEC_SIZE * 3)(%rdi), %xmm3
	PCMPEQ	%xmm2, %xmm3
	pand	%xmm1, %xmm3

	pmovmskb %xmm3, %eax
	CHECK_CMP (%ecx, %eax)
	jnz	L(ret_nonzero_vec_start_2_3)

	movups	(VEC_SIZE * -4 + SIZE_OFFSET)(%rsi, %rdx, CHAR_SIZE), %xmm0
	movups	(VEC_SIZE * -4 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm0, %xmm1
	movups	(VEC_SIZE * -3 + SIZE_OFFSET)(%rsi, %rdx, CHAR_SIZE), %xmm2
	movups	(VEC_SIZE * -3 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %xmm3
	PCMPEQ	%xmm2, %xmm3
	pand	%xmm1, %xmm3
	pmovmskb %xmm3, %eax
    subl    %ecx, %eax
#ifdef USE_AS_MEMCMPEQ
	jz	L(last_2x_vec)
	ret
	.p2align 5
#else	/* !USE_AS_MEMCMPEQ */
	jnz	L(ret_nonzero_vec_end_2)
#endif	/* !USE_AS_MEMnCMPEQ */

	.p2align 4
L(last_2x_vec):
	movups	(VEC_SIZE * -2 + SIZE_OFFSET)(%rsi, %rdx, CHAR_SIZE), %xmm0
	movups	(VEC_SIZE * -2 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %xmm1
	PCMPEQ	%xmm0, %xmm1
	movups	(VEC_SIZE * -1 + SIZE_OFFSET)(%rsi, %rdx, CHAR_SIZE), %xmm2
	movups	(VEC_SIZE * -1 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %xmm3
	PCMPEQ	%xmm2, %xmm3
	pand	%xmm1, %xmm3
	pmovmskb %xmm3, %eax
	subl	%ecx, %eax
#ifdef USE_AS_MEMCMPEQ
L(ret_nonzero_vec_start_2_3):
L(ret_nonzero_vec_end_2):
	ret
#else	/* !USE_AS_MEMCMPEQ */
	jnz	L(ret_nonzero_vec_end_1)
	ret

	.p2align 4,, 8
L(ret_nonzero_vec_end_1):
	pmovmskb %xmm1, %ecx
	rorl	$16, %eax
	xorl	%ecx, %eax
	/* Partial register stall.  */

	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	leal	(%rax, %rdx, CHAR_SIZE), %eax
	movl	(VEC_SIZE * -2 + SIZE_OFFSET)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * -2 + SIZE_OFFSET)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else	/* !USE_AS_WMEMCMP */
	addl	%edx, %eax
	movzbl	(VEC_SIZE * -2 + SIZE_OFFSET)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * -2 + SIZE_OFFSET)(%rdi, %rax), %eax

	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret

	.p2align 4
L(ret_nonzero_vec_start_2_3):
	pmovmskb %xmm1, %edx
	sall	$16, %eax
	leal	1(%rax, %rdx), %eax

	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 2)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 2)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else	/* !USE_AS_WMEMCMP */
	movzbl	(VEC_SIZE * 2)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 2)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret


	.p2align 4
L(ret_nonzero_vec_end_2):
	pmovmskb %xmm1, %ecx
	rorl	$16, %eax
	xorl	%ecx, %eax
	/* Partial register stall.  */

	bsfl	%eax, %eax
# ifdef USE_AS_WMEMCMP
	leal	(%rax, %rdx, CHAR_SIZE), %eax
	movl	(VEC_SIZE * -4 + SIZE_OFFSET)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * -4 + SIZE_OFFSET)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else	/* !USE_AS_WMEMCMP */
	addl	%edx, %eax
	movzbl	(VEC_SIZE * -4 + SIZE_OFFSET)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * -4 + SIZE_OFFSET)(%rdi, %rax), %eax

	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret


#endif	/* !USE_AS_MEMCMPEQ */

	.p2align 4
L(more_8x_vec):
	subq	%rdi, %rsi
	leaq	(VEC_SIZE * -6 + SIZE_OFFSET)(%rdi, %rdx, CHAR_SIZE), %rdx
	andq	$(VEC_SIZE * -1), %rdi
	addq	%rdi, %rsi
	.p2align 4
L(loop_4x):
	movups	(VEC_SIZE * 2)(%rsi), %xmm0
	movups	(VEC_SIZE * 3)(%rsi), %xmm1

	PCMPEQ	(VEC_SIZE * 2)(%rdi), %xmm0
	PCMPEQ	(VEC_SIZE * 3)(%rdi), %xmm1

	movups	(VEC_SIZE * 4)(%rsi), %xmm2
	movups	(VEC_SIZE * 5)(%rsi), %xmm3

	PCMPEQ	(VEC_SIZE * 4)(%rdi), %xmm2
	PCMPEQ	(VEC_SIZE * 5)(%rdi), %xmm3

	pand	%xmm0, %xmm1
	pand	%xmm2, %xmm3
	pand	%xmm1, %xmm3

	pmovmskb %xmm3, %eax
	subl	%ecx, %eax
	jnz	L(ret_nonzero_loop)

	addq	$(VEC_SIZE * 4), %rdi
	addq	$(VEC_SIZE * 4), %rsi
	cmpq	%rdi, %rdx
	ja	L(loop_4x)
	subq	%rdi, %rdx
	cmpl	$(VEC_SIZE * -2), %edx
	jle	L(loop_last_2x_vec)

	movups	(VEC_SIZE * 2)(%rsi), %xmm0
	movups	(VEC_SIZE * 2)(%rdi), %xmm1
	PCMPEQ	%xmm0, %xmm1
	movups	(VEC_SIZE * 3)(%rsi), %xmm2
	movups	(VEC_SIZE * 3)(%rdi), %xmm3
	PCMPEQ	%xmm2, %xmm3
	pand	%xmm1, %xmm3

	pmovmskb %xmm3, %eax
	CHECK_CMP (%ecx, %eax)
	jnz	L(ret_nonzero_vec_start_2_3)
L(loop_last_2x_vec):

	movups	(VEC_SIZE * 4)(%rsi, %rdx), %xmm0
	movups	(VEC_SIZE * 4)(%rdi, %rdx), %xmm1
	PCMPEQ	%xmm0, %xmm1
	movups	(VEC_SIZE * 5)(%rsi, %rdx), %xmm2
	movups	(VEC_SIZE * 5)(%rdi, %rdx), %xmm3
	PCMPEQ	%xmm2, %xmm3
	pand	%xmm1, %xmm3
	pmovmskb %xmm3, %eax

#ifndef USE_AS_MEMCMPEQ
	addl	$(VEC_SIZE * 6 - SIZE_OFFSET), %edx
#endif	/* !USE_AS_MEMCMPEQ */
#ifdef USE_AS_WMEMCMP
	shrl	$2, %edx
#endif	/* USE_AS_WMEMCMP */


	subl	%ecx, %eax
#ifdef USE_AS_MEMCMPEQ
L(ret_nonzero_loop):
	ret
#else	/* !USE_AS_MEMCMPEQ */
	jnz	L(ret_nonzero_vec_end_1)
	ret

	/* L(loop_ret_nonzero) and L(loop_tail_end) must be positioned
	   so that jumps from within L(loop_0x0) can get 2-byte
	   encoding. Otherwise the jump table with be incorrect.  */
	.p2align 4
L(ret_nonzero_loop):
	pmovmskb %xmm0, %ecx
	pmovmskb %xmm1, %edx
	sall	$(VEC_SIZE * 1), %edx
	leal	1(%rcx, %rdx), %edx
	pmovmskb %xmm2, %ecx
	rorl	$16, %eax
	xorl	%ecx, %eax

	salq	$32, %rax
	orq	%rdx, %rax

	bsfq	%rax, %rax
# ifdef USE_AS_WMEMCMP
	movl	(VEC_SIZE * 2)(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(VEC_SIZE * 2)(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
# else	/* !USE_AS_WMEMCMP */
	movzbl	(VEC_SIZE * 2)(%rsi, %rax), %ecx
	movzbl	(VEC_SIZE * 2)(%rdi, %rax), %eax
	subl	%ecx, %eax
# endif	/* !USE_AS_WMEMCMP */
	ret
#endif	/* !USE_AS_MEMCMPEQ */

END(MEMCMP)
