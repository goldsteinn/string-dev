#ifndef IN_STRCPY
# error "This file should only be included by strcpy"
#endif

#if HAS_LEN
# define ALIGNED_SRC_REG	r8
#else
# define ALIGNED_SRC_REG	rdx
#endif

#ifdef USE_AS_STRCAT
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %ALIGNED_SRC_REG
	movq	%rdi, %rax
	andq	$(VEC_SIZE * -1), %ALIGNED_SRC_REG
	VPCMPEQ	(%ALIGNED_SRC_REG), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	shrxl	%edi, %ecx, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	VEC_SIZE(%ALIGNED_SRC_REG), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	leaq	(VEC_SIZE)(%ALIGNED_SRC_REG), %rdi
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 2)(%ALIGNED_SRC_REG), %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v1)

	orq	$(VEC_SIZE * 2 - 1), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(1)(%rdi), %ymm0
	VPMIN	(VEC_SIZE + 1)(%rdi), %ymm0, %ymm1
	VPCMPEQ	%ymm1, %ymm7, %ymm1
	vpmovmskb %ymm1, %TMP_REG32
	subq	$(VEC_SIZE * -2), %rdi
	testl	%TMP_REG32, %TMP_REG32
	jz	L(loop_2x_vec)

	addq	$(VEC_SIZE * -2 + 1), %rdi

	VPCMPEQ	%ymm0, %ymm7, %ymm0
	vpmovmskb %ymm0, %ecx
	testl	%ecx, %ecx
	jnz	L(bsf_and_done_v0)

	movl	%TMP_REG32, %ecx

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsfl	%ecx, %ecx
	addq	%rcx, %rdi
#endif
