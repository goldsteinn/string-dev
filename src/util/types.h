#ifndef _SRC__UTIL__TYPES_H_
#define _SRC__UTIL__TYPES_H_

#include <limits.h>
#include <stdint.h>
#include <wchar.h>

/* Use safe_<type> for aliasing casts. */
typedef wchar_t  safe_wchar_t __attribute__((may_alias));
typedef uint32_t safe_uint32_t __attribute__((may_alias, aligned(1)));
typedef int32_t  safe_int32_t __attribute__((may_alias, aligned(1)));
typedef uint64_t safe_uint64_t __attribute__((may_alias, aligned(1)));
typedef int64_t  safe_int64_t __attribute__((may_alias, aligned(1)));

typedef char               safe_char __attribute__((may_alias, aligned(1)));
typedef unsigned char      safe_uchar __attribute__((may_alias, aligned(1)));
typedef short              safe_short __attribute__((may_alias, aligned(1)));
typedef unsigned short     safe_ushort __attribute__((may_alias, aligned(1)));
typedef int                safe_int __attribute__((may_alias, aligned(1)));
typedef unsigned int       safe_uint __attribute__((may_alias, aligned(1)));
typedef long               safe_long __attribute__((may_alias, aligned(1)));
typedef unsigned long      safe_ulong __attribute__((may_alias, aligned(1)));
typedef long long          safe_llong __attribute__((may_alias, aligned(1)));
typedef unsigned long long safe_ullong __attribute__((may_alias, aligned(1)));
typedef float              safe_float __attribute__((may_alias, aligned(1)));
typedef double             safe_double __attribute__((may_alias, aligned(1)));
typedef float              safe_float __attribute__((may_alias, aligned(1)));
typedef long double        safe_ldouble __attribute__((may_alias, aligned(1)));

typedef uint64_t ptr_int_t;

#ifndef __cplusplus
typedef int32_t bool;
static const bool false = 0;
static const bool true  = !false;
#endif

#define sizeof_bits(x) (sizeof(x) * CHAR_BIT)

#define CAST_TO_FUNC(func, x) ((FUNC_T(func))(x))
#define FUNC_T(func)          __typeof__(&(func))

#define CAST(x, y)            ((x)(y))
#define AGU(base, offset)     (CAST(ptr_int_t, base) + CAST(ptr_int_t, offset))
#define AGU_T(base, offset)   CAST(get_type(base), AGU(base, offset))

#ifdef __cplusplus
#include <type_traits>
#define UNSIGNED(x)     std::make_unsigned<get_type(x)>::type
#define UNSIGNED_PTR(x) UNSIGNED(x)
#else
#define UNSIGNED(x)                                                            \
    _Generic((x), char                                                         \
             : (unsigned char)(x), signed char                                 \
             : (unsigned char)(x), int                                         \
             : (unsigned int)(x), short                                        \
             : (unsigned short)(x), long                                       \
             : (unsigned long)(x), long long                                   \
             : (unsigned long long)(x), default                                \
             : x)

#define UNSIGNED_PTR(x)                                                        \
    _Generic((x), char *                            \
             : (unsigned char *)(x), signed char *  \
             : (unsigned char *)(x), int*           \
             : (unsigned int*)(x), short *          \
             : (unsigned short*)(x), long  *        \
             : (unsigned long*)(x), long long*      \
             : (unsigned long long*)(x), default    \
             : x)
#endif


#define get_type(x) __typeof__(x)
#define is_same_type(x, y)                                                     \
    __builtin_types_compatible_p(get_type(x), get_type(y))
#define is_same_func_type(decl, func)                                          \
    __builtin_types_compatible_p(get_type(decl), get_type(&(func)))


#endif
