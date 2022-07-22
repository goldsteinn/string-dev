#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"
#include "string-test-cpy-common.h"
#include "util/error-util.h"


#define run(dst, src, n)                                                       \
    CAST(                                                                      \
        uint8_t *,                                                             \
        (wsize == 4                                                            \
             ? CAST(uint8_t *,                                                 \
                    (with_len ? func.run_wcsncpy(                              \
                                    CAST(wchar_t *,                            \
                                         init_f == &init_wcsncat               \
                                             ? strcat_expec_ret(dst, s1, 4)    \
                                             : dst),                           \
                                    CAST(wchar_t const *, src), ((n) >> 2))    \
                              : func.run_wcscpy(                               \
                                    CAST(wchar_t *,                            \
                                         init_f == &init_wcscat                \
                                             ? strcat_expec_ret(dst, s1, 4)    \
                                             : dst),                           \
                                    CAST(wchar_t const *, src))))              \
             : CAST(                                                           \
                   uint8_t *,                                                  \
                   (with_len                                                   \
                        ? func.run_strncpy(                                    \
                              CAST(char *, (init_f == &init_strncat            \
                                                ? strcat_expec_ret(dst, s1, 1) \
                                                : dst)),                       \
                              CAST(char const *, src), (n))                    \
                        : func.run_strcpy(                                     \
                              CAST(char *, (init_f == &init_strcat             \
                                                ? strcat_expec_ret(dst, s1, 1) \
                                                : dst)),                       \
                              CAST(char const *, src))))))

#define strcat_expec_ret(s1_, s1_start_, sz_)                                  \
    ((s1_start_) + (((((s1_) - (s1_start_)) * 15) / 16) & (-CAST(uint64_t, sz_))))

static int32_t
check_strcat(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != strcat_expec_ret(s1, s1_start, 1)) {
        fprintf(stderr, "Bad Return (%p, %p, %p)\n", ret, s1, s1_start);
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }


    if (s1[len] != '\0') {
        fprintf(stderr, "No Term: %lu (%u)\n", len, s2[len] == '\0');
        return 4;
    }

    if (check_sentinel(s1 + len + 1, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}

static int32_t
check_wcscat(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != strcat_expec_ret(s1, s1_start, 4)) {
        fprintf(stderr, "Bad Return (%p, %p, %p)\n", ret, s1, s1_start);
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }

    uint32_t v = -1;
    memcpy(&v, s1 + len, 4);
    if (v != 0) {
        fprintf(stderr, "No Term: %lu (%u) (%u)\n", len, s2[len] == '\0', v);
        return 4;
    }

    if (check_sentinel(s1 + len + 4, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}


static int32_t
check_strcpy(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != s1) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }


    if (s1[len] != '\0') {
        fprintf(stderr, "No Term: %lu (%u)\n", len, s2[len] == '\0');
        return 4;
    }

    if (check_sentinel(s1 + len + 1, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}

static int32_t
check_wcscpy(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != s1) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }


    uint32_t v = -1;
    memcpy(&v, s1 + len, 4);
    if (v != 0) {
        fprintf(stderr, "No Term: %lu (%u) (%x)\n", len, s2[len] == '\0', v);
        return 4;
    }

    if (check_sentinel(s1 + len + 4, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}

static int32_t
check_stpcpy(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != s1 + len) {
        fprintf(stderr, "Bad Return (%p != %p)\n", ret, s1 + len);
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }


    if (s1[len] != '\0') {
        fprintf(stderr, "No Term: %lu (%u)\n", len, s2[len] == '\0');
        return 4;
    }

    if (check_sentinel(s1 + len + 1, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}


static int32_t
check_wcpcpy(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             const uint8_t * ret,
             uint64_t        n,
             uint64_t        len) {
    (void)(n);

    if (ret != s1 + len) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }


    uint32_t v = -1;
    memcpy(&v, s1 + len, 4);
    if (v != 0) {
        fprintf(stderr, "No Term: %lu (%u) (%x)\n", len, s2[len] == '\0', v);
        return 4;
    }

    if (check_sentinel(s1 + len + 4, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }

    return 0;
}


static int32_t
check_stpncpy(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {

    if (ret != s1 + MIN(len, n)) {
        fprintf(stderr, "Bad Return: %p != %p\n", ret, s1 + MIN(len, n));
        return 4;
    }


   uint64_t end_region = MIN(len, n);
    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (len < n) {
        if (check_region_is(s1 + len, 0, n - len)) {
            fprintf(stderr, "No zfill\n");
            for (uint64_t i = len; i < n; ++i) {
                if (s1[i] != '\0') {
                    fprintf(stderr, "%-6lu -> %x\n", i, s1[i]);
                }
            }
            return 1;
        }
    }

    if (check_region(s1, s2, end_region)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 1;
    }

    if (check_sentinel(s1 + n, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 1;
    }

    return 0;
}

static int32_t
check_strncpy(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {
    if (ret != s1) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    uint64_t end_region = MIN(len, n);
    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (len < n) {
        if (check_region_is(s1 + len, 0, n - len)) {
            fprintf(stderr, "No zfill\n");
            for (uint64_t i = len; i < n; ++i) {
                if (s1[i] != '\0') {
                    fprintf(stderr, "%-6lu -> %x\n", i, s1[i]);
                }
            }
            return 1;
        }
    }

    if (check_region(s1, s2, end_region)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 1;
    }

    if (check_sentinel(s1 + n, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 1;
    }

    return 0;
}

static int32_t
check_strlcpy(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {
    if (ret != s1) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    if (n == 0) {
        if (check_sentinel(s1_start, s1, START)) {
            fprintf(stderr, "Start Sentinel Error\n");
            return 1;
        }
        if (check_sentinel(s1 + len, s1_end, END)) {
            fprintf(stderr, "End Sentinel Error\n");
            return 3;
        }

        return 0;
    }

    uint64_t end = MIN(n - 1, len);


    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }
    if (check_region(s1, s2, end)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }
    if (check_sentinel(s1 + len, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }
    if (s1[n - 1] != '\0') {
        return 1;
    }
}

static int32_t
check_strlcat(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {


    if (ret != s1) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    if (n == 0) {
        if (check_sentinel(s1_start, s1, START)) {
            fprintf(stderr, "Start Sentinel Error\n");
            return 1;
        }
        if (check_sentinel(s1 + len, s1_end, END)) {
            fprintf(stderr, "End Sentinel Error\n");
            return 3;
        }

        return 0;
    }


    uint64_t end = MIN(len + 1, n - 1);

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (check_region(s1, s2, end)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 1;
    }

    if (check_sentinel(s1 + len, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 1;
    }

    if (s1[n - 1] != '\0') {
        return 1;
    }


    return 0;
}
static int32_t
check_strncat(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {


    if (ret != strcat_expec_ret(s1, s1_start, 1)) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    uint64_t end = MIN(len, n);
    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (len < n) {
        if (s1[len] != '\0') {
            fprintf(stderr, "No Term: %lu (%u, %u)\n", len, s1[len] == '\0',
                    s2[len] == '\0');
            return 4;
        }
    }
    else if (n) {
        if (s1[n - 1] == '\0') {
            fprintf(stderr, "Has Term: %lu (%u, %u)\n", len, s1[len] == '\0',
                    s2[len] == '\0');
            return 4;
        }
    }

    if (check_region(s1, s2, end)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 1;
    }

    if (check_sentinel(s1 + end + 1, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 1;
    }

    return 0;
}

static int32_t
check_wcsncat(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2,
              const uint8_t * ret,
              uint64_t        n,
              uint64_t        len) {

    if (ret != strcat_expec_ret(s1, s1_start, 4)) {
        fprintf(stderr, "Bad Return\n");
        return 4;
    }

    uint64_t end = MIN(len, n);
    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }

    if (len < n) {
        uint32_t v = -1;
        memcpy(&v, s1 + len, 4);
        if (v != 0) {
            fprintf(stderr, "No Term: %lu (%u, %u)\n", len, s1[len] == '\0',
                    s2[len] == '\0');
            return 4;
        }
    }
    else if (n) {
        uint32_t v = -1;
        memcpy(&v, s1 + n - 4, 4);
        if (v == 0) {
            fprintf(stderr, "Has Term: %lu (%u, %u)\n", len, s1[len] == '\0',
                    s2[len] == '\0');
            return 4;
        }
    }

    if (check_region(s1, s2, end)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 1;
    }

    if (check_sentinel(s1 + end + 4, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 1;
    }

    return 0;
}

static void
init_strcpy(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1, 0xff, len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 1);
}


static void
init_wcscpy(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1, 0xff, len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 4);
}


static void
init_strncpy(uint8_t * s1_start,
             uint8_t * s1_end,
             uint8_t * s1,
             uint64_t  len,
             uint64_t  n) {
    (void)(len);
    memset_c(s1_start, 0xff, (s1_end - s1_start));
    init_cpy_sentinels(s1_start, s1_end, s1, n);
}


static void
init_stpcpy(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1, 0xff, len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 1);
}

static void
init_wcpcpy(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1, 0xff, len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 4);
}

static void
init_strcat(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1_start, 0xff, (s1 - s1_start) + len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 1);
    *s1 = '\0';
}

static void
init_wcscat(uint8_t * s1_start,
            uint8_t * s1_end,
            uint8_t * s1,
            uint64_t  len,
            uint64_t  n) {
    (void)(n);
    memset_c(s1_start, 0xff, (s1 - s1_start) + len);
    init_cpy_sentinels(s1_start, s1_end, s1, len + 4);
    memset(s1, 0, 4);
}

static void
init_strncat(uint8_t * s1_start,
             uint8_t * s1_end,
             uint8_t * s1,
             uint64_t  len,
             uint64_t  n) {
    uint64_t end = MIN(len, n);
    memset_c(s1_start, 0xff, (s1 - s1_start) + end);
    init_cpy_sentinels(s1_start, s1_end, s1, end + 1);

    *s1 = '\0';
}

static void
init_wcsncat(uint8_t * s1_start,
             uint8_t * s1_end,
             uint8_t * s1,
             uint64_t  len,
             uint64_t  n) {
    uint64_t end = MIN(len, n);
    memset_c(s1_start, 0xff, (s1 - s1_start) + end);
    init_cpy_sentinels(s1_start, s1_end, s1, end + 4);

    memset(s1, 0, 4);
}


typedef FUNC_T(init_strcpy) init_func_t;
typedef FUNC_T(check_strcpy) check_func_t;

#define FAILURE_MSG                                                            \
    "al1=%lu, al2=%lu, i=%lu, j=%lu, k=%lu, n=%lu\n",                          \
        ((uint64_t)test1) % 4096, ((uint64_t)test2) % 4096, i, j, k, n
#define INIT_I 0
#define INIT_J 8
#define INIT_K 0
#define INIT_N 0

//#define VPRINT(...) fprintf(stderr, __VA_ARGS__)
#ifndef VPRINT
#define VPRINT(...)
#endif
static int32_t
test_strcpy_kernel(uint64_t     test_size,
                   void const * test_f,
                   check_func_t check_f,
                   init_func_t  init_f,
                   uint64_t     wsize) {
    func_switch_t func = { test_f };

    uint8_t * s1       = make_buf(test_size);
    uint8_t * s2       = make_buf(test_size);
    uint64_t  n        = 0;
    int32_t   with_len = 0;
    uint64_t  i, j, k;

    uint64_t wsize_shift = wsize == 4 ? 2 : 0;
    (void)(wsize_shift);
    die_assert(wsize == 1 || wsize == 4);

    memset_c(s1, 0xff, test_size);

    init_region(s2, test_size);
    uint8_t  zbytes[4] = { 0 };
    uint8_t *test1, *test2;
    uint64_t al_pairs[NPAIRS * 2] = { 0 };
    for (i = INIT_I; i < nalignments * 2; ++i) {
        uint64_t al_offset = ROUNDUP_P2(alignments[i % nalignments], wsize);
        fprintf(stderr, "%lu\n", i);
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }

        make_alignment_pairs(al_pairs, al_offset);

        uint64_t test_max = test_size - al_offset;
        for (j = INIT_J; j < test_max; j += wsize) {
            for (k = INIT_K; k < NPAIRS; ++k) {
                test1 = s1 + (al_pairs[S1_IDX(k)] & (-wsize));
                test2 = s2 + (al_pairs[S1_IDX(k)] & (-wsize));
                VPRINT("%lu:%lu:%lu\n", i, j, k);
                PRINTFFL;
                init_f(s1, s1 + test_size, test1, j, 0);
                PRINTFFL;
                memcpy(zbytes, test2 + j, wsize);
                PRINTFFL;
                memset(test2 + j, 0, wsize);
                PRINTFFL;
                uint8_t * r = run(test1, test2, j);
                PRINTFFL;
                test_assert(
                    check_f(s1, s1 + test_size, test1, test2, r, j, j) == 0,
                    FAILURE_MSG);
                PRINTFFL;
                memcpy(test2 + j, zbytes, wsize);
            }
        }
    }
    return 0;
}

static uint64_t
next_length(uint64_t l, uint64_t test_size, uint64_t wsize_shift) {
    const uint64_t lb   = (128 * 8 << wsize_shift);
    const uint64_t base = 4;
    if (l >= lb && (l <= (lb + (base << wsize_shift)))) {
        l = test_size;
        if (l >= lb && (l <= (lb + (base << wsize_shift)))) {
            __builtin_unreachable();
        }
        if (l < lb) {
            __builtin_unreachable();
        }
        return l;
    }

    if (l <= 400) {
        return l += (1 << wsize_shift);
    }

    return l += (((rand() % base) | 1) << wsize_shift);
}
static int32_t
test_strncpy_kernel(uint64_t     test_size,
                    void const * test_f,
                    check_func_t check_f,
                    init_func_t  init_f,
                    uint64_t     wsize) {
    func_switch_t func = { test_f };

    uint8_t * s1       = make_buf(test_size);
    uint8_t * s2       = make_buf(test_size);
    int32_t   with_len = 1;
    uint64_t  i, j, k, n;

    uint64_t wsize_shift = wsize == 4 ? 2 : 0;
    (void)(wsize_shift);
    die_assert(wsize == 1 || wsize == 4);

    memset_c(s1, 0xff, test_size);

    init_region(s2, test_size);
    uint8_t  zbytes[4] = { 0 };
    uint8_t *test1, *test2;
    uint64_t al_pairs[NPAIRS * 2] = { 0 };
    for (i = INIT_I; i < nalignments * 2; ++i) {
        uint64_t al_offset = ROUNDUP_P2(alignments[i % nalignments], wsize);
        fprintf(stderr, "%lu\n", i);
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }
        j = 0;
        n = 0;
        k = 0;
        make_alignment_pairs(al_pairs, al_offset);
        uint8_t * r;
        uint64_t  test_max = test_size - al_offset;
        for (j = INIT_J; j < test_max;
             j = next_length(j, test_size, wsize_shift)) {

            for (n = INIT_N; n < test_max;
                 n = next_length(n, test_size, wsize_shift)) {
                for (k = INIT_K; k < NPAIRS; ++k) {
                    VPRINT("%lu:%lu:%lu:%lu\n", i, j, n, k);
                    test1 = s1 + (al_pairs[S1_IDX(k)] & (-wsize));
                    test2 = s2 + (al_pairs[S1_IDX(k)] & (-wsize));

                    PRINTFFL;
                    init_f(s1, s1 + test_size, test1, j, n);
                    PRINTFFL;
                    memcpy(zbytes, test2 + j, wsize);
                    PRINTFFL;
                    memset(test2 + j, 0, wsize);
                    PRINTFFL;
                    r = run(test1, test2, n);
                    PRINTFFL;
                    test_assert(
                        check_f(s1, s1 + test_size, test1, test2, r, n, j) == 0,
                        FAILURE_MSG);


                    if (init_f == &init_strncat || init_f == &init_wcsncat) {
                        uint64_t of_len = ULONG_MAX;
                        for (; of_len >= (ULONG_MAX >> 2); of_len >>= 1) {
                            init_f(s1, s1 + test_size, test1, j, of_len);

                            r = run(test1, test2, of_len);
                            test_assert(check_f(s1, s1 + test_size, test1,
                                                test2, r, of_len, j) == 0,
                                        FAILURE_MSG);

                            init_f(s1, s1 + test_size, test1, j, of_len + 1);

                            r = run(test1, test2, of_len + 1);
                            test_assert(check_f(s1, s1 + test_size, test1,
                                                test2, r, of_len + 1, j) == 0,
                                        FAILURE_MSG);
                        }
                    }

                    PRINTFFL;
                    memcpy(test2 + j, zbytes, wsize);
                    init_f(s1, s1 + test_size, test1, ULONG_MAX, n);
                    r = run(test1, test2, n);
                    test_assert(check_f(s1, s1 + test_size, test1, test2, r, n,
                                        ULONG_MAX) == 0,
                                FAILURE_MSG);
                    if (i == 0) {
                        break;
                    }
                }
            }
        }
    }
    return 0;
}


int32_t
test_strcpy(void const * test_f) {
    test_assert(
        test_strcpy_kernel(4096, test_f, &check_strcpy, &init_strcpy, 1) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_strcpy, &init_strcpy, 1) == 0);
    return 0;
}
int32_t
test_strcat(void const * test_f) {
    test_assert(
        test_strcpy_kernel(4096, test_f, &check_strcat, &init_strcat, 1) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_strcat, &init_strcat, 1) == 0);
    return 0;
}
int32_t
test_stpcpy(void const * test_f) {

    test_assert(
        test_strcpy_kernel(4096, test_f, &check_stpcpy, &init_stpcpy, 1) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_stpcpy, &init_stpcpy, 1) == 0);
    return 0;
}

int32_t
test_strncpy(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_strncpy, &init_strncpy,
                                    1) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_strncpy, &init_strncpy,
                                    1) == 0);
    return 0;
}
int32_t
test_strncat(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_strncat, &init_strncat,
                                    1) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_strncat, &init_strncat,
                                    1) == 0);
    return 0;
}
int32_t
test_stpncpy(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_stpncpy, &init_strncpy,
                                    1) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_stpncpy, &init_strncpy,
                                    1) == 0);
    return 0;
}
int32_t
test_strlcpy(void const * test_f) {
    (void)(test_f);
    return 0;
}
int32_t
test_strlcat(void const * test_f) {
    (void)(test_f);
    return 0;
}


int32_t
test_wcscpy(void const * test_f) {
    test_assert(
        test_strcpy_kernel(4096, test_f, &check_wcscpy, &init_wcscpy, 4) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_wcscpy, &init_wcscpy, 4) == 0);
    return 0;
}
int32_t
test_wcscat(void const * test_f) {
    test_assert(
        test_strcpy_kernel(4096, test_f, &check_wcscat, &init_wcscat, 4) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_wcscat, &init_wcscat, 4) == 0);
    return 0;
}
int32_t
test_wcpcpy(void const * test_f) {
    test_assert(
        test_strcpy_kernel(4096, test_f, &check_wcpcpy, &init_wcpcpy, 4) == 0);
    test_assert(
        test_strcpy_kernel(8192, test_f, &check_wcpcpy, &init_wcpcpy, 4) == 0);
    return 0;
}

int32_t
test_wcsncpy(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_strncpy, &init_strncpy,
                                    4) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_strncpy, &init_strncpy,
                                    4) == 0);
    return 0;
}
int32_t
test_wcsncat(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_wcsncat, &init_wcsncat,
                                    4) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_wcsncat, &init_wcsncat,
                                    4) == 0);
    return 0;
}
int32_t
test_wcpncpy(void const * test_f) {
    test_assert(test_strncpy_kernel(4096, test_f, &check_stpncpy, &init_strncpy,
                                    4) == 0);
    test_assert(test_strncpy_kernel(8192, test_f, &check_stpncpy, &init_strncpy,
                                    4) == 0);
    return 0;
}
int32_t
test_wcslcpy(void const * test_f) {
    (void)(test_f);
    return 0;
}
int32_t
test_wcslcat(void const * test_f) {
    (void)(test_f);
    return 0;
}
