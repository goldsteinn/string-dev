/* strlen/strnlen/wcslen/wcsnlen optimized with 256-bit EVEX instructions.
   Copyright (C) 2021-2022 Free Software Foundation, Inc.
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

#if ISA_SHOULD_BUILD (4)


# ifndef STRLEN
#  define STRLEN	__strlen_evex
# endif

# ifndef VEC_SIZE
#  include "../../libc-defs/libc-evex256-vecs.h"
# endif

# ifdef USE_AS_WCSLEN
#  define USE_AS_WCSCPY
#  define VPCMPEQ	vpcmpeqd
#  define VPCMPNEQ	vpcmpneqd
#  define VPTESTN	vptestnmd
#  define VPTEST	vptestmd
#  define VPMIN	vpminud
#  define CHAR_SIZE	4
#  define CHAR_SIZE_SHIFT_REG(reg)	sar $2, %reg
# else
#  define VPCMPEQ	vpcmpeqb
#  define VPCMPNEQ	vpcmpneqb
#  define VPTESTN	vptestnmb
#  define VPTEST	vptestmb
#  define VPMIN	vpminub
#  define CHAR_SIZE	1
#  define CHAR_SIZE_SHIFT_REG(reg)

#  define REG_WIDTH	VEC_SIZE
# endif

# define CHAR_PER_VEC	(VEC_SIZE / CHAR_SIZE)

# include "../../libc-defs/libc-reg-macros.h"

# if CHAR_PER_VEC == 64

#  define TAIL_RETURN_LBL	first_vec_x2
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 2)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x3
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 3)

# else

#  define TAIL_RETURN_LBL	first_vec_x3
#  define TAIL_RETURN_OFFSET	(CHAR_PER_VEC * 3)

#  define FALLTHROUGH_RETURN_LBL	first_vec_x2
#  define FALLTHROUGH_RETURN_OFFSET	(CHAR_PER_VEC * 2)
# endif

# define VZERO_128	VMM_128(0)
# define VZERO	VMM(0)
# define PAGE_SIZE	4096

	.section SECTION(.text), "ax", @progbits
ENTRY_P2ALIGN(STRLEN, 6)
	movq	%rdi, %rax
	/* Paired down strlen implementation for str{n}cat-
	   evex{256|512}. Copyright (C) 2022 Free Software Foundation,
	   Inc. This file is part of the GNU C Library. The GNU C
	   Library is free software; you can redistribute it and/or
	   modify it under the terms of the GNU Lesser General Public
	   License as published by the Free Software Foundation; either
	   version 2.1 of the License, or (at your option) any later
	   version. The GNU C Library is distributed in the hope that
	   it will be useful, but WITHOUT ANY WARRANTY; without even
	   the implied warranty of MERCHANTABILITY or FITNESS FOR A
	   PARTICULAR PURPOSE.  See the GNU Lesser General Public
	   License for more details. You should have received a copy of
	   the GNU Lesser General Public License along with the GNU C
	   Library; if not, see <https://www.gnu.org/licenses/>.  */

	vpxorq	%VZERO_128, %VZERO_128, %VZERO_128
	/* Paired down strlen implementation.  We never commit to 4x
	   loop as we are expecting a relatively short string and want
	   to minimize code size.  */
	movq	%rdi, %r8
	andq	$(VEC_SIZE * -1), %r8
	VPCMPEQ	(%r8), %VZERO, %k0
	KMOV	%k0, %VRCX
# ifdef USE_AS_WCSCPY
	subl	%r8d, %edi
	shrl	$2, %edi
# endif
	shrx	%VRDI, %VRCX, %VRCX
# ifdef USE_AS_WCSCPY
	movq	%rax, %rdi
# endif
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)


	VPCMPEQ	(VEC_SIZE * 1)(%r8), %VZERO, %k0
	KMOV	%k0, %VRCX
	leaq	(VEC_SIZE)(%r8), %rdi
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	VPCMPEQ	(VEC_SIZE * 1)(%rdi), %VZERO, %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v1)

	VPCMPEQ	(VEC_SIZE * 2)(%rdi), %VZERO, %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v2)

	VPCMPEQ	(VEC_SIZE * 3)(%rdi), %VZERO, %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v3)

	andq	$-(VEC_SIZE * 4), %rdi
	.p2align 4,, 8
L(loop_2x_vec):
	VMOVA	(VEC_SIZE * 4)(%rdi), %VMM(0)
	VPMIN	(VEC_SIZE * 5)(%rdi), %VMM(0), %VMM(1)
	VMOVA	(VEC_SIZE * 6)(%rdi), %VMM(2)
	VPMIN	(VEC_SIZE * 7)(%rdi), %VMM(2), %VMM(3)
	VPTESTN	%VMM(1), %VMM(1), %k2
	VPTESTN	%VMM(2), %VMM(3), %k4
	subq	$(VEC_SIZE * -4), %rdi
	KORTEST	%k2, %k4
	jz	L(loop_2x_vec)


	VPTESTN	%VMM(0), %VMM(0), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v0)

	KMOV	%k2, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v1)

	VPTESTN	%VMM(2), %VMM(2), %k0
	KMOV	%k0, %VRCX
	test	%VRCX, %VRCX
	jnz	L(bsf_and_done_v2)

	KMOV	%k4, %VRCX
L(bsf_and_done_v3):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v2):
	bsf	%VRCX, %VRCX
	leaq	(VEC_SIZE * 2)(%rdi, %rcx, CHAR_SIZE), %rdi
	jmp	L(strcat_strlen_done)

	.p2align 4,, 4
L(bsf_and_done_v1):
	addq	$VEC_SIZE, %rdi
L(bsf_and_done_v0):
	bsf	%VRCX, %VRCX
# ifdef USE_AS_WCSCPY
	leaq	(%rdi, %rcx, CHAR_SIZE), %rdi
# else
	addq	%rcx, %rdi
# endif
L(strcat_strlen_done):
	subq	%rax, %rdi
	movq	%rdi, %rax
	shrq	$2, %rax
	ret


END(STRLEN)
#endif
