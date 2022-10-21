#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"

#define run(s0, s1, n)                                                         \
    (wsize == 4 ? (with_len ? func.run_wcsncmp(CAST(wchar_t const *, s0),      \
                                               CAST(wchar_t const *, s1), (n)) \
                            : func.run_wcscmp(CAST(wchar_t const *, s0),       \
                                              CAST(wchar_t const *, s1)))      \
                : (with_len ? func.run_strncmp(CAST(char const *, s0),         \
                                               CAST(char const *, s1), (n))    \
                            : func.run_strcmp(CAST(char const *, s0),          \
                                              CAST(char const *, s1))))


static int
strcmp_expec(const void * s1,
             const void * s2,
             size_t       len1,
             size_t       len2,
             size_t       len,
             size_t       pos) {
    //    return strcmp(s1, s2);
    PRINTFFL;
    if (len1 == len2 && pos > len1) {
        PRINTFFL;
        return 0;
    }
    PRINTFFL;

    PRINTFFL;
    uint64_t idx = MIN(pos, len1, len2);

    const uint8_t * c1  = (const uint8_t *)s1 + idx;
    const uint8_t * c2  = (const uint8_t *)s2 + idx;
    uint8_t         _c1 = *c1;
    uint8_t         _c2 = *c2;
    PRINTFFL;

    for (uint32_t i = 0; 0 && i < 1; ++i) {
        fprintf(stderr, "%-2u(%d): %x vs %x\n", i, i == idx,
                ((const char *)s1)[i] & 0xff, ((const char *)s2)[i] & 0xff);
    }
    (void)(len);
    return _c1 - _c2;
}


static int
wcscmp_expec(const void * s1,
             const void * s2,
             size_t       len1,
             size_t       len2,
             size_t       len,
             size_t       pos) {
    PRINTFFL;
    if (len1 == len2 && pos > len1) {
        PRINTFFL;
        return 0;
    }
    PRINTFFL;

    PRINTFFL;
    uint64_t idx = MIN(pos, len1, len2);
    PRINTFFL;
    (void)(len);
    const safe_wchar_t * c1  = (const safe_wchar_t *)(s1 + idx);
    const safe_wchar_t * c2  = (const safe_wchar_t *)(s2 + idx);
    safe_wchar_t         _c1 = *c1;
    safe_wchar_t         _c2 = *c2;
    return _c1 == _c2 ? 0 : (_c1 < _c2 ? -1 : 1);
}


static int
strncmp_expec(const void * s1,
              const void * s2,
              size_t       len1,
              size_t       len2,
              size_t       len,
              size_t       pos) {
    if (len1 == len2 && pos > len1) {
        return 0;
    }

    uint64_t idx = MIN(len1, len2, pos);
    if (idx >= len) {
        return 0;
    }
    const uint8_t * c1  = (const uint8_t *)s1 + idx;
    const uint8_t * c2  = (const uint8_t *)s2 + idx;
    uint8_t         _c1 = *c1;
    uint8_t         _c2 = *c2;
    return _c1 - _c2;
}


static int
wcsncmp_expec(const void * s1,
              const void * s2,
              size_t       len1,
              size_t       len2,
              size_t       len,
              size_t       pos) {
    len *= sizeof(wchar_t);
    if (len1 == len2 && pos > len1) {
        return 0;
    }

    uint64_t idx = MIN(len1, len2, pos);
    if (idx >= len) {
        return 0;
    }

    const safe_wchar_t * c1  = (const safe_wchar_t *)(s1 + idx);
    const safe_wchar_t * c2  = (const safe_wchar_t *)(s2 + idx);
    safe_wchar_t         _c1 = *c1;
    safe_wchar_t         _c2 = *c2;
    return _c1 == _c2 ? 0 : (_c1 < _c2 ? -1 : 1);
}

#define INIT_I      0
#define INIT_J      0
#define INIT_K      0
#define INIT_L0     0
#define INIT_L1     0
#define INIT_NP     0
//#define PRINTV(...) fprintf(stderr, __VA_ARGS__)

#ifndef PRINTV
#define PRINTV(...)
#endif


#define TEST_ERR                                                                                      \
    "(r != e): (%d != %d): align=%zu: %zu(%zu, %zu), pos=%zu, len0=%zu, len1=%zu, n=%zu, wsize=%u\n", \
        res, expec, i, np, al_pairs[S1_IDX(np)], al_pairs[S1_IDX(np)], j, l0,                         \
        l1, k, wsize

#define STRCMP_EQ(x, y)                                                        \
    ((((x) == 0) == ((y) == 0)) && (((x) < 0) == ((y) < 0)) &&                 \
     (((x) > 0) == ((y) > 0)))
static int
test_strcmp_kernel(void const * test_f,
                   FUNC_T(strcmp_expec) expec_f,
                   uint32_t test_size,
                   uint32_t with_len,
                   uint32_t wsize) {
    func_switch_t func = { test_f };

    uint8_t *s0, *s1, *test_s0, *test_s1;

    s0 = make_buf(test_size);
    s1 = make_buf(test_size);

    memset_c(s0, 0x12, test_size);
    memcpy_c(s1, s0, test_size);

    test_size = ROUNDDOWN_P2(test_size, wsize);

    uint64_t al_pairs[NPAIRS * 2] = { 0 };
    for (uint64_t i = INIT_I; i < nalignments * 2; ++i) {
        uint64_t al_offset = alignments[i % nalignments];
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        al_offset = ROUNDDOWN_P2(al_offset, wsize);
        make_alignment_pairs(al_pairs, al_offset);

        fprintf(stderr, "%zu\n", i);

        for (uint64_t j = INIT_J; j + al_offset < test_size;
             j          = ((next_v(j, test_size) + (wsize - 1)) & (-wsize))) {
            //            fprintf(stderr, "%zu-%zu\n", i, j);
            for (uint64_t l0 = INIT_L0 ? INIT_L0 : (j > 260 ? (j - 260) : 0);
                 l0 + al_offset < MIN(test_size, j + 260);
                 l0 = next_v2(l0, j, wsize)) {
#if 0
                for (uint64_t l1 = INIT_L1 ? INIT_L1
                                           : (j > 260 ? (j - 260) : 0);
                     l1 + al_offset < MIN(test_size, j + 260);
                     l1 = next_v2(l1, l0, wsize)) {
#endif
                {
                    uint64_t l1 = l0;
                    for (uint64_t k = INIT_K ? INIT_K
                                             : (j > 260 ? (j - 260) : 0);
                         k + al_offset < MIN(test_size, j + 260);
                         k = next_v2(k, j, wsize)) {
                        PRINTV("%zu:%zu:%zu:%zu:%zu\n", i, j, l0, l1, k);
                        for (uint64_t np = 0; np < NPAIRS; ++np) {

                            int res, expec;
                            test_s0 = s0 + (al_pairs[S1_IDX(np)] & (-wsize));
                            test_s1 = s1 + (al_pairs[S2_IDX(np)] & (-wsize));


                            memset_c(test_s0 + l0, 0x0, wsize);
                            memset_c(test_s1 + l1, 0x0, wsize);


                            expec = expec_f(test_s0, test_s1, l0, l1, k, -1UL);
                            res   = run(test_s0, test_s1, k);
                            test_assert(STRCMP_EQ(res, expec), TEST_ERR);

                            expec = -expec;
                            res   = run(test_s1, test_s0, k);
                            test_assert(STRCMP_EQ(res, expec), TEST_ERR);


                            memset_c(test_s0 + j, 0x11, wsize);

                            res   = run(test_s0, test_s1, k);
                            expec = expec_f(test_s0, test_s1, l0, l1, k, j);

                            test_assert(STRCMP_EQ(res, expec), TEST_ERR);

                            res   = run(test_s1, test_s0, k);
                            expec = -expec;

                            test_assert(STRCMP_EQ(res, expec), TEST_ERR);


                            if (with_len) {
                                uint64_t of_k = -1UL;
                                int      expec0, expec1;
                                expec0 =
                                    expec_f(test_s0, test_s1, l0, l1, of_k, j);
                                expec1 =
                                    expec_f(test_s1, test_s0, l0, l1, of_k, j);

                                res = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);


                                of_k = (1UL << 63);
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = (1UL << 62);
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = (uint64_t)test_s0;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = (uint64_t)test_s1;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = -(uint64_t)test_s0;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = -(uint64_t)test_s1;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = 1UL - (uint64_t)test_s0;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = 1UL - (uint64_t)test_s1;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);
                                of_k = -1UL - (uint64_t)test_s0;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);

                                of_k = 1UL - (uint64_t)test_s1;
                                res  = run(test_s0, test_s1, of_k);
                                test_assert(STRCMP_EQ(res, expec0), TEST_ERR);

                                res = run(test_s1, test_s0, of_k);
                                test_assert(STRCMP_EQ(res, expec1), TEST_ERR);
                            }

                            memset_c(test_s0 + j, 0x12, wsize);
                            memset_c(test_s0 + l0, 0x12, wsize);
                            memset_c(test_s1 + l1, 0x12, wsize);
                        }
                        if (!with_len) {
                            break;
                        }
                    }
                }
            }
        }
    }
    return 0;
}

int
test_strcmp(void const * test_f) {
    test_assert(
        test_strcmp_kernel(test_f, &strcmp_expec, PAGE_SIZE * 2, 0, 1) == 0);

    test_assert(test_strcmp_kernel(test_f, &strcmp_expec, PAGE_SIZE, 0, 1) ==
                0);

    return 0;
}

int
test_strncmp(void const * test_f) {
    test_assert(test_strcmp_kernel(test_f, &strncmp_expec, PAGE_SIZE, 1, 1) ==
                0);
    test_assert(
        test_strcmp_kernel(test_f, &strncmp_expec, PAGE_SIZE * 2, 1, 1) == 0);
    return 0;
}


int
test_wcscmp(void const * test_f) {
    test_assert(test_strcmp_kernel(test_f, &wcscmp_expec, PAGE_SIZE, 0, 4) ==
                0);
    test_assert(
        test_strcmp_kernel(test_f, &wcscmp_expec, PAGE_SIZE * 2, 0, 4) == 0);
    return 0;
}

int
test_wcsncmp(void const * test_f) {
    test_assert(test_strcmp_kernel(test_f, &wcsncmp_expec, PAGE_SIZE, 1, 4) ==
                0);
    test_assert(
        test_strcmp_kernel(test_f, &wcsncmp_expec, PAGE_SIZE * 2, 1, 4) == 0);
    return 0;
}
