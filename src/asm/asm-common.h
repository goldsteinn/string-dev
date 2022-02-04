#ifndef _SRC__ASM__ASM_COMMON_H_
#define _SRC__ASM__ASM_COMMON_H_

#define USE_MULTIARCH
#define IS_IN(x) 1

#define L(name)          L##name
#define NAME_LABEL(name) name##:

#define ENTRY_DEF(name)                                                        \
    .globl name;                                                               \
    .type  name, @function;                                                    \
    NAME_LABEL(name)                                                           \
    cfi_startproc;

#define ENTRY_END(name)                                                        \
    ENTRY_DEF(name)                                                            \
    NOP4

#define END_DEF(name)                                                          \
    cfi_endproc;                                                               \
    .size name, .- name;

#define ALIGNARG(log2) (1 << (log2))
#define ENTRY_P2ALIGN(name, alignment)                                         \
    .align ALIGNARG(alignment);                                                \
    ENTRY_END(name)


#define PAGE_ALIGN_CODE .align 4096;
#ifndef ALIGN_ENTRY
#define ALIGN_ENTRY 0
#endif

#if ALIGN_ENTRY == 0
#define ENTRY(name) ENTRY_P2ALIGN(name, 4)

#elif ALIGN_ENTRY == 48
#define ENTRY_P2ALIGN(name)                                                    \
    PAGE_ALIGN_CODE;                                                           \
    nop;                                                                       \
    .align 32;                                                                 \
    nop;                                                                       \
    .align 16;                                                                 \
    ENTRY_END(name)

#else
#define ENTRY(name)                                                            \
    PAGE_ALIGN_CODE;                                                           \
    nop;                                                                       \
    .align ALIGN_ENTRY;                                                        \
    ENTRY_END(name)
#endif

#if ALIGN_ENTRY == 0
#define END(name) END_DEF(name)
#else
#define END(name)                                                              \
    END_DEF(name)                                                              \
    PAGE_ALIGN_CODE;
#endif


#define ZERO_UPPER_VEC_REGISTERS_RETURN VZEROUPPER_RETURN
#define VZEROUPPER_RETURN                                                      \
    VZEROUPPER;                                                                \
    ret

#define RAX_LP rax
#define RDI_LP rdi
#define RSI_LP rsi
#define RDX_LP rdx
#define RCX_LP rcx

#define R8_LP r8
#define R9_LP r9

#define R10_LP r10
#define R11_LP r11
#define R12_LP r12
#define R13_LP r13

#define cfi_startproc              .cfi_startproc
#define cfi_endproc                .cfi_endproc
#define cfi_def_cfa(reg, off)      .cfi_def_cfa reg, off
#define cfi_def_cfa_register(reg)  .cfi_def_cfa_register reg
#define cfi_def_cfa_offset(off)    .cfi_def_cfa_offset off
#define cfi_adjust_cfa_offset(off) .cfi_adjust_cfa_offset off
#define cfi_offset(reg, off)       .cfi_offset reg, off
#define cfi_rel_offset(reg, off)   .cfi_rel_offset reg, off
#define cfi_register(r1, r2)       .cfi_register r1, r2
#define cfi_return_column(reg)     .cfi_return_column reg
#define cfi_restore(reg)           .cfi_restore reg
#define cfi_same_value(reg)        .cfi_same_value reg
#define cfi_undefined(reg)         .cfi_undefined reg
#define cfi_remember_state         .cfi_remember_state
#define cfi_restore_state          .cfi_restore_state
#define cfi_window_save            .cfi_window_save
#define cfi_personality(enc, exp)  .cfi_personality enc, exp
#define cfi_lsda(enc, exp)         .cfi_lsda enc, exp

#include "nops.h"

#endif