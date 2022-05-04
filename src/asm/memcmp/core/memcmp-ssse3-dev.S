#include "../../libc-asm-common.h"

	/* Do not implement wmemcmp in this file. The code size here is
	   quite expensive ~1500byte more than the sse2 version. memcmp
	   is hot enough to justify the code size for speed, wmemcmp is
	   not.  */

	/* Long term note: At some point memcmpeq optimizations will get
	   into distro llvm/gcc. Once common distros start including
	   memcmpeq the memcmp portion of this can be dropped as the
	   function will become significantly less hot.  */
#if 1
# include "memcmp-sse2-dev.S"
#else
# ifdef USE_AS_MEMCMPEQ
#  define loop_sub	%ecx
# else
#  define loop_sub	$0xffff
# endif

# define PCMPEQ	pcmpeqb



ENTRY(MEMCMP)
	// Range       : [0, 18446744073709551615]
	// % Of Calls  : 100.0
	// branch      : T = 23.02, NT = 76.98
	cmpq	$16, %rdx
	ja	L(LB17_UBinf)

	// Range       : [0, 16]
	// % Of Calls  : 76.98
	// branch      : T = 32.43, NT = 67.57
	cmpl	$8, %edx
	ja	L(LB9_UB16)

	// Range       : [0, 8]
	// % Of Calls  : 52.01
	// branch      : T = 20.4, NT = 79.6
	cmpl	$4, %edx
	jb	L(LB0_UB3)

	// Range       : [4, 8]
	// % Of Calls  : 41.41
	// copy        :
# ifdef USE_AS_MEMCMPEQ
	movl	0(%rsi), %eax
	subl	0(%rdi), %eax

	movl	-4(%rsi, %rdx), %esi
	subl	-4(%rdi, %rdx), %esi

	orl	%esi, %eax
	ret
# else
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
# endif

	// Range       : [9, 16]
	// % Of Calls  : 24.97
	// copy        :
	.p2align 4,, 10
L(LB9_UB16):
# ifdef USE_AS_MEMCMPEQ
	movq	0(%rsi), %rax
	subq	0(%rdi), %rax

	movq	-8(%rsi, %rdx), %rcx
	subq	-8(%rdi, %rdx), %rcx
	orq	%rcx, %rax
	/* Convert 64 bit -> 32 bit boolean.  */
	setnz	%cl
	movzbl	%cl, %eax
# else
	movq	0(%rsi), %rcx
	movq	0(%rdi), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)

	movq	-8(%rsi, %rdx), %rcx
	movq	-8(%rdi, %rdx), %rax
	cmpq	%rcx, %rax
	jnz	L(ret_nonzero)
	xorl	%eax, %eax
# endif
	ret


# ifndef USE_AS_MEMCMPEQ
	.p2align 4,, 14
L(ret_nonzero):
	bswapq	%rcx
	bswapq	%rax
	subq	%rcx, %rax
	sbbl	%eax, %eax
	orl	$1, %eax
	ret
# endif






	// Range       : [0, 3]
	// % Of Calls  : 10.61
	// branch      : T = 12.18, NT = 87.82
	.p2align 4
L(LB0_UB3):
# ifdef USE_AS_MEMCMPEQ
	cmpl	$1, %edx
	jbe	L(LB0_UB1)
#  define MOVZBL_OFFSET	(-1)
# else
	decl	%edx
	jle	L(LB0_UB1)
#  define MOVZBL_OFFSET	0
# endif


	// Range       : [2, 3]
	// % Of Calls  : 9.32
	// copy        :
	movzbl	MOVZBL_OFFSET(%rsi, %rdx), %ecx
	movzbl	MOVZBL_OFFSET(%rdi, %rdx), %eax

# undef MOVZBL_OFFSET

	sall	$16, %ecx
	sall	$16, %eax

	movzwl	0(%rsi), %esi
	movzwl	0(%rdi), %edi

	orl	%esi, %ecx
	orl	%edi, %eax

# ifdef USE_AS_MEMCMPEQ
	subl	%ecx, %eax
	/* Return already 32-bit.  */
# else
	cmpl	%ecx, %eax
	jnz	L(ret_nonzero)
L(LB0_UB0):
	xorl	%eax, %eax
# endif
	ret

	// Range       : [0, 1]
	// % Of Calls  : 1.29
	// branch      : T = 0.01, NT = 99.99
	.p2align 4,, 8
L(LB0_UB1):
	jl	L(LB0_UB0)

	// Range       : [1, 1]
	// % Of Calls  : 1.29
	// copy        :
	movzbl	0(%rdi), %eax
	movzbl	0(%rsi), %ecx
	subl	%ecx, %eax
	ret
# ifdef USE_AS_MEMCMPEQ
L(LB0_UB0):
	xorl	%eax, %eax
	ret
# endif


	// Range       : [17, 18446744073709551615]
	// % Of Calls  : 23.02
	// branch      : T = 23.35, NT = 76.65
	.p2align 5
L(LB17_UBinf):
	movups	0(%rsi), %xmm0
	movups	0(%rdi), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_vec_start_0)

	cmpq	$32, %rdx
	ja	L(LB33_UBinf_H1_16)

	movups	-16(%rsi, %rdx), %xmm0
	movups	-16(%rdi, %rdx), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
# ifndef USE_AS_MEMCMPEQ
	/* Don't use `incw ax` as machines this code runs on are liable
	   to have partial register stall.  */
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_vec_end_0)
# else
L(ret_nonzero_vec_start_0):
L(ret_nonzero_vec_end_0):
# endif
	ret

# ifndef USE_AS_MEMCMPEQ
	.p2align 4,, 6
L(ret_nonzero_vec_start_16):
	sall	$16, %eax
L(ret_nonzero_vec_start_0):
	bsfl	%eax, %eax
#  ifdef USE_AS_WMEMCMP
	movl	(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#  else
	movzbl	(%rsi, %rax), %ecx
	movzbl	(%rdi, %rax), %eax
	subl	%ecx, %eax
#  endif
	ret

	/* Crosses fetch block no matter what.  */
	.p2align 4,, 4
L(ret_nonzero_vec_end_16):
	subl	$16, %edx
L(ret_nonzero_vec_end_0):
	bsfl	%eax, %eax
	addl	%edx, %eax
#  ifdef USE_AS_WMEMCMP
	movl	-16(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	-16(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#  else
	movzbl	-16(%rsi, %rax), %ecx
	movzbl	-16(%rdi, %rax), %eax
	subl	%ecx, %eax
#  endif
	ret
# endif

	.p2align 5
L(LB33_UB64_H1_16):
	movups	16(%rsi), %xmm0
	movups	16(%rdi), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	subl	$0xffff, %eax
	jnz	L(ret_nonzero_vec_start_16)
L(last_2x_vec):
	movups	-16(%rsi, %rdx), %xmm1
	movups	-16(%rdi, %rdx), %xmm3
	PCMPEQ	%xmm3, %xmm1
	movups	-32(%rsi, %rdx), %xmm0
	movups	-32(%rdi, %rdx), %xmm2
	PCMPEQ	%xmm2, %xmm0
# ifdef USE_AS_MEMCMPEQ
	pand	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
	subl	%ecx, %eax
L(ret_nonzero_vec_start_16):
L(ret_nonzero_vec_end_16):
# else
	pmovmskb %xmm1, %eax
	pmovmskb %xmm0, %ecx
	sall	$16, %eax
	orl	%ecx, %eax
	incl	%eax
	jnz	L(ret_nonzero_vec_end_16)
# endif
	ret


	// Range       : [33, 18446744073709551615]
	// % Of Calls  : 5.37
	// branch      : T = 32.56, NT = 67.44
	.p2align 4,, 4
L(LB33_UBinf_H1_16):
# ifdef USE_AS_MEMCMPEQ
	movl	$0xffff, %ecx
# endif

	cmpq	$64, %rdx
	jbe	L(LB33_UB64_H1_16)

	movl	%edi, %eax
	subl	%esi, %eax
	leaq	-64(%rsi, %rdx), %rdx

	andl	$0xf, %eax

	addq	%rax, %rsi
	andq	$-16, %rsi
	andq	$-16, %rdi
	movaps	(%rsi), %xmm0
	sall	$5, %eax
	leaq	L(loop_start)(%rip), %r9
	leal	(%rax, %rax, 2), %eax

	addq	%r9, %rax
	jmp	* %rax



# ifndef USE_AS_MEMCMPEQ
	/* L(loop_ret_nonzero) and L(loop_tail_end) must be positioned
	   so that jumps from within L(loop_0x0) can get 2-byte
	   encoding. Otherwise the jump table with be incorrect.  */
	.p2align 4
L(loop_ret_nonzero):
	pmovmskb %xmm2, %edx
	pmovmskb %xmm1, %ecx
	sall	$16, %edx
	salq	$32, %rax
	orl	%ecx, %edx
	notl	%edx
	orq	%rdx, %rax
	bsfq	%rax, %rax
#  ifdef USE_AS_WMEMCMP
	movl	16(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	16(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#  else
	movzbl	16(%rsi, %rax), %ecx
	movzbl	16(%rdi, %rax), %eax
	subl	%ecx, %eax
#  endif
	ret

	.p2align 4
L(loop_tail_end):
	bsfl	%eax, %eax
#  ifdef USE_AS_WMEMCMP
	movl	48(%rdi, %rax), %ecx
	xorl	%edx, %edx
	cmpl	48(%rsi, %rax), %ecx
	/* NB: no partial register stall here because xorl zero idiom
	   above.  */
	setg	%dl
	leal	-1(%rdx, %rdx), %eax
#  else
	movzbl	48(%rdi, %rcx), %eax
	movzbl	48(%rsi, %rcx), %ecx
	subl	%ecx, %eax
#  endif
	ret
# endif


	/* Code alignment and size is important. Each L(loop_{align_by})
	   is [65, 96] bytes with a .p2align 5 inbetween. This is
	   necessary for correctness as the indirect will take the
	   address of L(lop_start) and add 96 * misalignment to get the
	   proper loop. If any code changes re-confirm the loops are
	   still properly aligned.  */
	.p2align 5
L(loop_start):
L(loop_0x0):
	movaps	16(%rsi), %xmm1
	movaps	32(%rsi), %xmm2
	movaps	48(%rsi), %xmm3
	PCMPEQ	16(%rdi), %xmm1
	PCMPEQ	32(%rdi), %xmm2
	PCMPEQ	48(%rdi), %xmm3
	pand	%xmm1, %xmm2
	pand	%xmm2, %xmm3
	pmovmskb %xmm3, %eax
	subl	loop_sub, %eax
	jnz	L(loop_ret_nonzero)
	addq	$48, %rsi
	addq	$48, %rdi
	cmpq	%rsi, %rdx
	ja	L(loop_0x0)
L(loop_tail):
	subq	%rsi, %rdx
	cmpl	$-32, %edx
	ja	L(last_2x_vec)

	/* Remaining length.  */
	movups	48(%rsi, %rdx), %xmm0
	movups	48(%rdi, %rdx), %xmm1
	PCMPEQ	%xmm1, %xmm0
	pmovmskb %xmm0, %eax
# ifdef USE_AS_MEMCMPEQ
	subl	loop_sub, %eax
# else
	/* Save code size as expensive of partial register stall on non-
	   zero return.  */
	incw	%ax
# endif
	jnz	L(loop_tail_end)

# ifdef USE_AS_MEMCMPEQ
L(loop_ret_nonzero):
L(loop_tail_end):
# endif
	ret
	/* NB: no bytes to spare before next block.  */

# define PRIMITIVE_ALIGNED_LOOP(align_by, ne_target, local_return)	\
	.p2align 5;	\
L(loop_ ## align_by):	\
	movaps	48(%rsi), %xmm3;	\
	movaps	32(%rsi), %xmm2;	\
	movaps	16(%rsi), %xmm1;	\
	movaps	%xmm3, %xmm4;	\
	palignr	$align_by, %xmm2, %xmm3;	\
	palignr	$align_by, %xmm1, %xmm2;	\
	palignr	$align_by, %xmm0, %xmm1;	\
	PCMPEQ	48(%rdi), %xmm3;	\
	PCMPEQ	32(%rdi), %xmm2;	\
	PCMPEQ	16(%rdi), %xmm1;	\
	pand	%xmm2, %xmm3;	\
	pand	%xmm1, %xmm3;	\
	pmovmskb %xmm3, %eax;	\
	subl	loop_sub, %eax;	\
	jne	L(ne_target);	\
	movaps	%xmm4, %xmm0;	\
	addq	$48, %rsi;	\
	addq	$48, %rdi;	\
	cmpq	%rsi, %rdx;	\
	ja	L(loop_ ## align_by);	\
	jmp	L(loop_tail);	\
L(loop_ ## align_by ## _end):	\
	local_return;

// abf-off
#ifdef USE_AS_MEMCMPEQ
# define ALIGNED_LOOP(align_by)	\
	PRIMITIVE_ALIGNED_LOOP (	\
	align_by,	\
	loop_ ## align_by ## _end,	\
	ret	\
	)
#else
# define ALIGNED_LOOP(align_by)	\
	PRIMITIVE_ALIGNED_LOOP (	\
	align_by,	\
	loop_ret_nonzero,	\
	;	\
	)
#endif
// abf-on

	ALIGNED_LOOP (0xf)
	ALIGNED_LOOP (0xe)
	ALIGNED_LOOP (0xd)
	ALIGNED_LOOP (0xc)
	ALIGNED_LOOP (0xb)
	ALIGNED_LOOP (0xa)
	ALIGNED_LOOP (0x9)
	ALIGNED_LOOP (0x8)
	ALIGNED_LOOP (0x7)
	ALIGNED_LOOP (0x6)
	ALIGNED_LOOP (0x5)
	ALIGNED_LOOP (0x4)
	ALIGNED_LOOP (0x3)
	ALIGNED_LOOP (0x2)
	ALIGNED_LOOP (0x1)
END(MEMCMP)
#endif
