#include "test/test-common.h"

#include "util/common.h"
#include "util/inline-math.h"
#include "util/types.h"

#include "string-func-switches.h"
#include "string-test-common.h"


static int
expec_memcmp(void const * s0, void const * s1, uint64_t len, uint64_t pos) {
    uint8_t const * s0_c;
    uint8_t const * s1_c;

    if (pos >= len) {
        return 0;
    }
    s0_c = (uint8_t const *)s0;
    s1_c = (uint8_t const *)s1;

    unsigned s0_v = *(s0_c + pos);
    unsigned s1_v = *(s1_c + pos);

    return s1_v > s0_v ? -1 : (s1_v == s0_v ? 0 : 1);
}


static int
expec_wmemcmp(void const * s0, void const * s1, uint64_t len, uint64_t pos) {
    safe_wchar_t const * s0_c;
    safe_wchar_t const * s1_c;

    if (pos >= len) {
        return 0;
    }
    assert((pos & 3) == 0);
    assert((CAST(uint64_t, s0) & 3) == 0);
    assert((CAST(uint64_t, s1) & 3) == 0);

    s0_c = (safe_wchar_t const *)s0;
    s1_c = (safe_wchar_t const *)s1;

    wchar_t s0_v = *(s0_c + (pos / sizeof(wchar_t)));
    wchar_t s1_v = *(s1_c + (pos / sizeof(wchar_t)));

    return s1_v > s0_v ? -1 : (s1_v == s0_v ? 0 : 1);
}


int
check_memcmpeq(int          res,
               void const * s0,
               void const * s1,
               uint64_t     len,
               uint64_t     pos) {
    int expec_res = expec_memcmp(s0, s1, len, pos);
    int ret       = (res == 0) == (expec_res == 0);
    if (!ret) {
        fprintf(stderr, "%d != %d\n", res, expec_res);
    }
    return ret;
}

int
check_memcmp(int          res,
             void const * s0,
             void const * s1,
             uint64_t     len,
             uint64_t     pos) {
    int expec_res = expec_memcmp(s0, s1, len, pos);
    int ret       = ((res == 0) == (expec_res == 0)) &&
              ((res > 0) == (expec_res > 0)) && ((res < 0) == (expec_res < 0));
    if (!ret) {
        fprintf(stderr, "%d != %d\n", res, expec_res);
    }
    return ret;
}

int
check_wmemcmp(int          res,
              void const * s0,
              void const * s1,
              uint64_t     len,
              uint64_t     pos) {
    int expec_res = expec_wmemcmp(s0, s1, len, pos);
    int ret       = ((res == 0) == (expec_res == 0)) &&
              ((res > 0) == (expec_res > 0)) && ((res < 0) == (expec_res < 0));
    if (!ret) {
        fprintf(stderr, "%d != %d\n", res, expec_res);
    }
    return ret;
}

#define run(s0, s1, n)                                                         \
    (wsize == 4 ? func.run_wmemcmp(CAST(wchar_t const *, s0),                  \
                                   CAST(wchar_t const *, s1), (n) / 4)         \
                : func.run_memcmp(CAST(char const *, s0),                      \
                                  CAST(wchar_t const *, s1), n))


#define INIT_I 0
#define INIT_J 0
#define INIT_K 0
#define INIT_L 0

#define FAILURE_MSG                                                            \
    "%u, %u, %u, %u (%u: %lu, %lu)\n", i, j, k, l, al_offset,                  \
        al_pairs[S1_IDX(l)], al_pairs[S2_IDX(l)]
static int
test_memcmp_kernel(void const * test_f,
                   FUNC_T(check_memcmp) check_f,
                   uint32_t test_size) {
    const uint32_t wsize = (check_f == &check_wmemcmp) ? 4 : 1;
    func_switch_t  func  = { test_f };

    uint8_t *s0, *s1, *test_s0, *test_s1;

    s0 = make_buf(test_size);
    s1 = make_buf(test_size);

    memset_c(s0, 0x12, test_size);
    memcpy_c(s1, s0, test_size);

    test_size = ROUNDDOWN_P2(test_size, wsize);
    //    test_assert(run(s0, s1, test_size) == 0, FAILURE_MSG);
    uint64_t al_pairs[NPAIRS * 2] = { 0 };
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = alignments[i % nalignments];
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        al_offset = ROUNDDOWN_P2(al_offset, wsize);
        make_alignment_pairs(al_pairs, al_offset);

        fprintf(stderr, "%u\n", i);
        for (uint32_t j = INIT_J; j + al_offset < test_size; j += wsize) {
            memset_c(s0 + al_offset + j, 0x11, test_size - (al_offset + j));
            memset_c(s1 + al_offset + j, 0x10, test_size - (al_offset + j));
            memset_c(s0, 0x12, al_offset + j);
            memset_c(s1, 0x12, al_offset + j);
            for (uint32_t k = INIT_K; k <= j;
                 k          = ROUNDUP_P2(
                              k < (512 + 256) ? k + wsize : next_v(k, PAGE_SIZE),
                     wsize)) {
                for (uint32_t l = INIT_L; l < NPAIRS; ++l) {
                    uint8_t save0[4] = { 0 }, save1[4] = { 0 };


                    test_s0 = s0 + ROUNDDOWN_P2(al_pairs[S1_IDX(l)], wsize);
                    test_s1 = s1 + ROUNDDOWN_P2(al_pairs[S2_IDX(l)], wsize);
                    //                    fprintf(stderr, FAILURE_MSG);
                    test_assert(run(test_s0, test_s1, j) == 0, FAILURE_MSG);
                    if (k == j) {
                        continue;
                    }

                    memcpy_c(save0, test_s0 + k, wsize);
                    memcpy_c(save1, test_s1 + k, wsize);
                    test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                        test_s1, j, k),
                                FAILURE_MSG);

                    uint8_t *dst, *save;
                    dst  = test_s0;
                    save = save0;
                    for (uint32_t m = 0; m < 2; ++m) {
                        int new_v = 0;
                        memcpy_c(&new_v, save, wsize);
                        new_v -= 1;
                        memcpy_c(dst + k, &new_v, wsize);
                        test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                            test_s1, j, k),
                                    FAILURE_MSG);
                        new_v -= 2;
                        memcpy_c(dst + k, &new_v, wsize);
                        test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                            test_s1, j, k),
                                    FAILURE_MSG);

                        new_v += 2;
                        new_v ^= (1u << ((8 * wsize) - 1));
                        memcpy_c(dst + k, &new_v, wsize);
                        test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                            test_s1, j, k),
                                    FAILURE_MSG);

                        new_v ^= (1u << ((8 * wsize) - 1));
                        new_v = ~new_v;
                        memcpy_c(dst + k, &new_v, wsize);
                        test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                            test_s1, j, k),
                                    FAILURE_MSG);

                        new_v = -new_v;
                        memcpy_c(dst + k, &new_v, wsize);
                        test_assert(check_f(run(test_s0, test_s1, j), test_s0,
                                            test_s1, j, k),
                                    FAILURE_MSG);

                        memcpy_c(dst + k, save, wsize);
                        dst  = test_s1;
                        save = save1;
                    }
                    memcpy_c(test_s0 + k, save0, wsize);
                    memcpy_c(test_s1 + k, save1, wsize);
                }
            }
        }
    }

    return 0;
}

int
test_memcmp_common(void const * test_f, FUNC_T(check_memcmp) check_f) {
    return test_memcmp_kernel(test_f, check_f, 4096);
}

int
test_memcmp(void const * test_f) {
    return test_memcmp_common(test_f, &check_memcmp);
}
int
test_memcmpeq(void const * test_f) {
    return test_memcmp_common(test_f, &check_memcmpeq);
}

int
test_wmemcmp(void const * test_f) {
    return test_memcmp_common(test_f, &check_wmemcmp);
}
