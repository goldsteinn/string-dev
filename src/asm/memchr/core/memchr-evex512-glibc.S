#include "../../libc-asm-common.h"

#if ISA_SHOULD_BUILD (4)

# ifndef MEMCHR
#  define MEMCHR	__memchr_evex
# endif
# define VEC_SIZE	64
# ifdef USE_AS_WMEMCHR
#  define CHAR_SIZE	4
#  define VPBROADCAST	vpbroadcastd
#  define VPCMP	vpcmpd
# else
#  define CHAR_SIZE	1
#  define VPBROADCAST	vpbroadcastb
#  define VPCMP	vpcmpb
# endif

# define PAGE_SIZE	4096
# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)
# define XMM1	xmm17

# if VEC_SIZE == 64
#  define KMOV	kmovq
#  define KOR	korq
#  define KORTEST	kortestq
#  define RAX	rax
#  define RCX	rcx
#  define SHR	shrq
#  define SARX	sarxq
#  define TEXTSUFFIX	evex512
#  define VMM0	zmm16
# elif VEC_SIZE == 32
	/* Currently Unused.  */
#  define KMOV	kmovd
#  define KOR	kord
#  define KORTEST	kortestd
#  define RAX	eax
#  define RCX	ecx
#  define SHR	shrl
#  define SARX	sarxl
#  define TEXTSUFFIX	evex256
#  define VMM0	ymm16
# endif

	.section .text.TEXTSUFFIX, "ax", @progbits
	/* Aligning entry point to 64 byte, provides better performance
	   for one vector length string.  */
ENTRY_P2ALIGN(MEMCHR, 6)
# ifndef USE_AS_RAWMEMCHR
	/* Check for zero length.  */
	test	%RDX_LP, %RDX_LP
	jz	L(zero)

#  ifdef __ILP32__
	/* Clear the upper 32 bits.  */
	movl	%edx, %edx
#  endif
# endif

	/* Broadcast CHAR to VMM0.  */
	VPBROADCAST %esi, %VMM0
	movl	%edi, %eax
	andl	$(PAGE_SIZE - 1), %eax
	cmpl	$(PAGE_SIZE - VEC_SIZE), %eax
	ja	L(page_cross)

	/* Compare [w]char for null, mask bit will be set for match.  */
	VPCMP	$0, (%rdi), %VMM0, %k0

	KMOV	%k0, %RAX
# ifndef USE_AS_RAWMEMCHR
	bsf	%RAX, %RCX
	jz	L(align_more)
	xor	%eax, %eax
#  ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#  else
	addq	%rcx, %rdi
#  endif
	cmp	%rcx, %rdx
	cmova	%rdi, %rax
# else
	bsf	%RAX, %RAX
	jz	L(align_more)
	add	%rdi, %rax
# endif
	ret

# ifndef USE_AS_RAWMEMCHR
L(zero):
	xorl	%eax, %eax
	ret
# endif

	.p2align 5,, 5
L(page_cross):
	movq	%rdi, %rcx
	andq	$-VEC_SIZE, %rcx

	VPCMP	$0, (%rcx), %VMM0, %k0
	KMOV	%k0, %RCX
	SARX	%RAX, %RCX, %RAX
# ifndef USE_AS_RAWMEMCHR
	bsf	%RAX, %RCX
	jz	L(align_more)
	xor	%eax, %eax
#  ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
#  else
	addq	%rcx, %rdi
#  endif
	cmp	%rcx, %rdx
	cmovae	%rdi, %rax

# else
	bsf	%rax, %rax
	jz	L(align_more)
	add	%rdi, %rax
# endif
	ret

L(ret_vec_x2):
	subq	$-VEC_SIZE, %rdi
L(ret_vec_x1):
	bsf	%RAX, %RAX
# ifndef USE_AS_RAWMEMCHR
	jz	L(zero)
	cmp	%rax, %rdx
	jbe	L(zero)
# endif
# ifdef USE_AS_WMEMCHR
	leaq	(%rdi, %rax, CHAR_SIZE), %rax
# else
	add	%rdi, %rax
# endif
	ret

	.p2align 5,, 10
L(align_more):
# ifndef USE_AS_RAWMEMCHR
	xor	%eax, %eax
	subq	%rdi, %rax
# endif

	subq	$-VEC_SIZE, %rdi
	/* Align rdi to VEC_SIZE.  */
	andq	$-VEC_SIZE, %rdi

# ifndef USE_AS_RAWMEMCHR
	addq	%rdi, %rax
#  ifdef USE_AS_WMEMCHR
	sarl	$2, %eax
#  endif
	subq	%rax, %rdx
	jbe	L(zero)
# endif

	/* Loop unroll 4 times for 4 vector loop.  */
	VPCMP	$0, (%rdi), %VMM0, %k0

	KMOV	%k0, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x1)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	VPCMP	$0, VEC_SIZE(%rdi), %VMM0, %k0

	KMOV	%k0, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x2)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	VPCMP	$0, (VEC_SIZE * 2)(%rdi), %VMM0, %k0

	KMOV	%k0, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x3)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	VPCMP	$0, (VEC_SIZE * 3)(%rdi), %VMM0, %k0

	KMOV	%k0, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x4)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
	/* Save pointer to find alignment adjustment.  */
	movq	%rdi, %rax
# endif
	/* Align address to VEC_SIZE * 4 for loop.  */
	andq	$-(VEC_SIZE * 4), %rdi

	/* Add alignment difference to rdx.  */
# ifndef USE_AS_RAWMEMCHR
	subq	%rdi, %rax
#  ifdef USE_AS_WMEMCHR
	SHR	$2, %RAX
#  endif
	addq	%rax, %rdx
	jmp	L(loop_entry)
# endif

	/* 4 vector loop.  */
	.p2align 5,, 11
L(loop):
# ifndef USE_AS_RAWMEMCHR
	subq	$(CHAR_PER_VEC * 4), %rdx
	jbe	L(zero)
L(loop_entry):
# endif
	VPCMP	$0, (VEC_SIZE * 4)(%rdi), %VMM0, %k1
	VPCMP	$0, (VEC_SIZE * 5)(%rdi), %VMM0, %k2
	VPCMP	$0, (VEC_SIZE * 6)(%rdi), %VMM0, %k3
	VPCMP	$0, (VEC_SIZE * 7)(%rdi), %VMM0, %k4
	KOR	%k1, %k2, %k5
	KOR	%k3, %k4, %k6

	subq	$-(VEC_SIZE * 4), %rdi
	KORTEST	%k5, %k6
	jz	L(loop)

	KMOV	%k1, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x1)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	KMOV	%k2, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x2)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	KMOV	%k3, %RAX
	test	%RAX, %RAX
	jnz	L(ret_vec_x3)

# ifndef USE_AS_RAWMEMCHR
	subq	$CHAR_PER_VEC, %rdx
	jbe	L(zero)
# endif

	/* At this point null [w]char must be in the fourth vector so no
	   need to check.  */
	KMOV	%k4, %RAX

L(ret_vec_x4):
	bsf	%RAX, %RAX
# ifndef USE_AS_RAWMEMCHR
	cmp	%rax, %rdx
	jbe	L(zero)
# endif
	leaq	(VEC_SIZE * 3)(%rdi, %rax, CHAR_SIZE), %rax
	ret

	.p2align 5,, 5
L(ret_vec_x3):
	bsf	%RAX, %RAX
# ifndef USE_AS_RAWMEMCHR
	cmp	%rax, %rdx
	jbe	L(zero)
# endif
	leaq	(VEC_SIZE * 2)(%rdi, %rax, CHAR_SIZE), %rax
	ret

END(MEMCHR)
#endif
