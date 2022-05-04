
#include "../libc-asm-common.h"
ENTRY(MEMCPY)
	cmpq	$32, %rdx
	ja	L(LB33_UBinf_H1_16)

	leaq	L(small_copies_start)(%rip), %rcx
	sall	$4, %edx
	addq	%rdx, %rcx
	jmp	* %rcx

	// Range       : [33, 64]
	// % Of Calls  : 0.86
	// copy        :
	.p2align 4,, 4
L(LB33_UB64_H1_16):
	movups	16(%rsi), %xmm1

	movups	%xmm0, 0(%rdi)
	movups	%xmm1, 16(%rdi)
	movups	%xmm6, -32(%rdi, %rdx)
	movups	%xmm7, -16(%rdi, %rdx)
L(nop):
	ret

	// Range       : [33, 18446744073709551615]
	// % Of Calls  : 23.17
	// branch      : T = 3.72, NT = 96.28
	.p2align 4,, 4
L(LB33_UBinf_H1_16):
	movups	(%rsi), %xmm0
	movups	-16(%rsi, %rdx), %xmm7
	movups	-32(%rsi, %rdx), %xmm6
	cmpq	$64, %rdx
	jbe	L(LB33_UB64_H1_16)


	leaq	L(loop_fwd_start)(%rip), %r9

	/* We use rcx later to get alignr value.  */
	movl	%esi, %ecx

	/* For memmove safety.  */
	subl	%edi, %ecx



	/* -16(%rsi, %rdx) already loaded into xmm7.  */


	movups	-48(%rsi, %rdx), %xmm5

	andl	$0xf, %ecx
	subq	%rcx, %rsi
	sall	$6, %ecx

	addq	%rcx, %r9


	andq	$-16, %rsi

	movups	%xmm0, (%rdi)

	movaps	16(%rsi), %xmm0

	leaq	-64(%rdi, %rdx), %r8

	andq	$-16, %rdi

	movl	$48, %edx
	jmp	* %r9



	/* Instead of a typical jump table all 16 loops are exactly
	   64-bytes in size. So, we can just jump to first loop + r8 *
	   64. Before modifying any loop ensure all their sizes match!
	 */
	.p2align 6
L(loop_fwd_start):
L(loop_fwd_0x0):
	movaps	16(%rsi), %xmm1
	movaps	32(%rsi), %xmm2
	movaps	48(%rsi), %xmm3
	movaps	%xmm1, 16(%rdi)
	movaps	%xmm2, 32(%rdi)
	movaps	%xmm3, 48(%rdi)
	addq	%rdx, %rdi
	addq	%rdx, %rsi
	cmpq	%rdi, %r8
	ja	L(loop_fwd_0x0)
L(end_loop_fwd):
	movups	%xmm5, 16(%r8)
	movups	%xmm6, 32(%r8)
	movups	%xmm7, 48(%r8)
	ret


#define ALIGNED_LOOP_FWD(align_by);	\
	.p2align 6;	\
L(loop_fwd_ ## align_by):	\
	movaps	32(%rsi), %xmm1;	\
	movaps	48(%rsi), %xmm2;	\
	movaps	64(%rsi), %xmm3;	\
	movaps	%xmm3, %xmm4;	\
	palignr	$align_by, %xmm2, %xmm3;	\
	palignr	$align_by, %xmm1, %xmm2;	\
	palignr	$align_by, %xmm0, %xmm1;	\
	movaps	%xmm4, %xmm0;	\
	movaps	%xmm1, 16(%rdi);	\
	movaps	%xmm2, 32(%rdi);	\
	movaps	%xmm3, 48(%rdi);	\
	addq	%rdx, %rdi;	\
	addq	%rdx, %rsi;	\
	cmpq	%rdi, %r8;	\
	ja	L(loop_fwd_ ## align_by);	\
	jmp	L(end_loop_fwd);

	ALIGNED_LOOP_FWD (0x1)
	ALIGNED_LOOP_FWD (0x2)
	ALIGNED_LOOP_FWD (0x3)
	ALIGNED_LOOP_FWD (0x4)
	ALIGNED_LOOP_FWD (0x5)
	ALIGNED_LOOP_FWD (0x6)
	ALIGNED_LOOP_FWD (0x7)
	ALIGNED_LOOP_FWD (0x8)
	ALIGNED_LOOP_FWD (0x9)
	ALIGNED_LOOP_FWD (0xa)
	ALIGNED_LOOP_FWD (0xb)
	ALIGNED_LOOP_FWD (0xc)
	ALIGNED_LOOP_FWD (0xd)
	ALIGNED_LOOP_FWD (0xe)
	ALIGNED_LOOP_FWD (0xf)


	.p2align 4
L(small_copies_start):
L(copy_0):
	ret
	.p2align 4
L(copy_1):
	movzbl	(%rsi), %ecx
	movb	%cl, (%rdi)
	ret

	.p2align 4
L(copy_2):
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
	ret

	.p2align 4
L(copy_3):
	movzwl	(%rsi), %ecx
	movzbl	2(%rsi), %edx
	movw	%cx, (%rdi)
	movb	%dl, 2(%rdi)
	ret

	.p2align 4
L(copy_4):
	movl	(%rsi), %ecx
	movl	%ecx, (%rdi)
	ret

	.p2align 4
L(copy_5):
	movl	(%rsi), %ecx
	movzbl	4(%rsi), %edx
	movl	%ecx, (%rdi)
	movb	%dl, 4(%rdi)
	ret

	.p2align 4
L(copy_6):
	movl	(%rsi), %ecx
	movzwl	4(%rsi), %edx
	movl	%ecx, (%rdi)
	movw	%dx, 4(%rdi)
	ret

	.p2align 4
L(copy_7):
	movl	(%rsi), %ecx
	movl	3(%rsi), %edx
	movl	%ecx, (%rdi)
	movl	%edx, 3(%rdi)
	ret

	.p2align 4
L(copy_8):
	movq	(%rsi), %rcx
	movq	%rcx, (%rdi)
	ret

	.p2align 4
L(copy_9):
	movq	(%rsi), %rcx
	movzbl	8(%rsi), %edx
	movq	%rcx, (%rdi)
	movb	%dl, 8(%rdi)
	ret

	.p2align 4
L(copy_10):
	movq	(%rsi), %rcx
	movzwl	8(%rsi), %edx
	movq	%rcx, (%rdi)
	movw	%dx, 8(%rdi)
	ret

	.p2align 4
L(copy_11):
	movq	(%rsi), %rcx
	movl	7(%rsi), %edx
	movq	%rcx, (%rdi)
	movl	%edx, 7(%rdi)
	ret

	.p2align 4
L(copy_12):
	movq	(%rsi), %rcx
	movl	8(%rsi), %edx
	movq	%rcx, (%rdi)
	movl	%edx, 8(%rdi)
	ret

	.p2align 4
L(copy_13):
	movq	(%rsi), %rcx
	movq	5(%rsi), %rdx
	movq	%rcx, (%rdi)
	movq	%rdx, 5(%rdi)
	ret

	.p2align 4
L(copy_14):
	movq	(%rsi), %rcx
	movq	6(%rsi), %rdx
	movq	%rcx, (%rdi)
	movq	%rdx, 6(%rdi)
	ret

	.p2align 4
L(copy_15):
	movq	(%rsi), %rcx
	movq	7(%rsi), %rdx
	movq	%rcx, (%rdi)
	movq	%rdx, 7(%rdi)
	ret

	.p2align 4
L(copy_16):
	movups	(%rsi), %xmm0
	movups	%xmm0, (%rdi)
	ret

	.p2align 4
L(copy_17):
	movups	(%rsi), %xmm0
	movzbl	16(%rsi), %edx
	movups	%xmm0, (%rdi)
	movb	%dl, 16(%rdi)
	ret


	.p2align 4
L(copy_18):
	movups	(%rsi), %xmm0
	movzwl	16(%rsi), %edx
	movups	%xmm0, (%rdi)
	movw	%dx, 16(%rdi)
	ret

	.p2align 4
L(copy_19):
	movups	(%rsi), %xmm0
	movl	15(%rsi), %edx
	movups	%xmm0, (%rdi)
	movl	%edx, 15(%rdi)
	ret

	.p2align 4
L(copy_20):
	movups	(%rsi), %xmm0
	movl	16(%rsi), %edx
	movups	%xmm0, (%rdi)
	movl	%edx, 16(%rdi)
	ret

	.p2align 4
L(copy_21):
	movups	(%rsi), %xmm0
	movq	13(%rsi), %rdx
	movups	%xmm0, (%rdi)
	movq	%rdx, 13(%rdi)
	ret


	.p2align 4
L(copy_22):
	movups	(%rsi), %xmm0
	movq	14(%rsi), %rdx
	movups	%xmm0, (%rdi)
	movq	%rdx, 14(%rdi)
	ret

	.p2align 4
L(copy_23):
	movups	(%rsi), %xmm0
	movq	15(%rsi), %rdx
	movups	%xmm0, (%rdi)
	movq	%rdx, 15(%rdi)
	ret

	.p2align 4
L(copy_24):
	movups	(%rsi), %xmm0
	movq	16(%rsi), %rdx
	movups	%xmm0, (%rdi)
	movq	%rdx, 16(%rdi)
	ret

	.p2align 4
L(copy_25):
	movups	(%rsi), %xmm0
	movups	9(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 9(%rdi)
	ret

	.p2align 4
L(copy_26):
	movups	(%rsi), %xmm0
	movups	10(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 10(%rdi)
	ret

	.p2align 4
L(copy_27):
	movups	(%rsi), %xmm0
	movups	11(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 11(%rdi)
	ret

	.p2align 4
L(copy_28):
	movups	(%rsi), %xmm0
	movups	12(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 12(%rdi)
	ret

	.p2align 4
L(copy_29):
	movups	(%rsi), %xmm0
	movups	13(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 13(%rdi)
	ret

	.p2align 4
L(copy_30):
	movups	(%rsi), %xmm0
	movups	14(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 14(%rdi)
	ret

	.p2align 4
L(copy_31):
	movups	(%rsi), %xmm0
	movups	15(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 15(%rdi)
	ret


	.p2align 4
L(copy_32):
	movups	(%rsi), %xmm0
	movups	16(%rsi), %xmm1
	movups	%xmm0, (%rdi)
	movups	%xmm1, 16(%rdi)
	ret

END(MEMCPY)
