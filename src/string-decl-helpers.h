#ifndef _SRC__STRING_DECL_HELPERS_H_
#define _SRC__STRING_DECL_HELPERS_H_

#define func_info_name(func)  CAT(func, _info)
#define test_name(func)       CAT(test_, func)
#define init_name(func)       CAT(func, _bench_init)
#define make_bench_name(base) CAT(base, _make_bench)

#define I__make_func_info1(func, base)                                         \
    static func_info_t const func_info_name(func) = {                          \
        CAST(void const *, &func), CAST(void const *, &test_name(base)),       \
        CAST(void const *, &bench_name(func)),                                 \
        CAST(void const *, &init_name(base))                                   \
    }

#define I__make_func_info0(...) I__make_func_info1(__VA_ARGS__)
#define make_func_info(pp)      I__make_func_info0(DEPAREN(pp))


#define make_string_decl(func)                                                 \
    {                                                                          \
        V_TO_STR(func), {                                                      \
            CAST(void const *, &func_info_name(func))                          \
        }                                                                      \
    }


#define expand_impl(func) CAT(func, _dev), CAT(func, _glibc)
#define expand_impls(...) APPLY2(expand_impl, COMMA, __VA_ARGS__)

#define decl_func(base, fwd_decl, ...)                                         \
    extern int32_t test_name(base)(void const *);                              \
    APPLY(fwd_decl, ;, __VA_ARGS__);                                           \
    APPLY(make_bench_name(base), ;, __VA_ARGS__);                              \
    APPLY(make_func_info, ;, APPLY_PACKL(base, __VA_ARGS__))


#endif
