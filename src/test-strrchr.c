#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"

#define run(s, c)                                                              \
    CAST(uint8_t *,                                                            \
         wsize == 4                                                            \
             ? CAST(uint8_t *, func.run_wcsrchr(CAST(wchar_t const *, s),      \
                                                CAST(wchar_t, c)))             \
             : CAST(uint8_t *, func.run_strrchr(CAST(char const *, s), c)))

static void
set_priors(uint8_t *      buf,
           const uint32_t wsize,
           uint32_t       setv,
           uint32_t       ub,
           uint32_t       inc) {
    die_assert(wsize == 1 || wsize == 4);


    for (uint32_t m = 0; m < ub; m += inc) {
        if (wsize == 1) {
            __builtin_memcpy(buf + m, &setv, 1);
        }
        else {
            __builtin_memcpy(buf + m, &setv, 4);
        }
    }
}

#define FAILURE_MSG                                                            \
    "%p != %p, align=%u(%u), pos=%u, len=%u\n", res, expec, i, al_offset, j, k

#define FAILURE_MSG2                                                           \
    "%p != %p, align=%u(%u), pos=%u, len=%u, inc=%u\n", res, expec, i,         \
        al_offset, j, k, inc
#define INIT_I   0
#define INIT_J   0
#define INIT_K   0
#define INIT_INC 12
static int
test_strrchr_kernel(void const *   test_f,
                    const uint32_t wsize,
                    uint32_t       test_size) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;

    memset_c(buf, 0xff, test_size);
    test_size = ROUNDDOWN_P2(test_size, wsize);
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = ROUNDUP_P2(alignments[i % nalignments], wsize);
        fprintf(stderr, "%u\n", i);
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }

        uint32_t test_max = test_size - al_offset;
        for (uint32_t j = INIT_J; j < test_max; j += wsize) {
            for (uint32_t k = INIT_K; k < MIN(test_max, j + 164);
                 k          = ROUNDUP_P2(next_v(k, test_size), wsize)) {
                //                fprintf(stderr, "%u, %u, %u\n", i, j, k);
                test_buf = buf + al_offset;
                uint8_t *res, *expec;
                for (uint32_t inc = INIT_INC ? INIT_INC : 12; 1 && inc < 128;
                     inc += 12) {
                    set_priors(test_buf, wsize, 0x01010101, j, inc);
                    memset_c(test_buf + j, 0x01, wsize);
                    memset_c(test_buf + k, 0x0, wsize);

                    res = run(test_buf, 0x01010101);
                    if (k && (j != k || j != 0)) {
                        if (j >= k) {
                            expec = test_buf + (k - ((k - 1) % inc) - 1);
                        }
                        else {
                            expec = test_buf + j;
                        }
                    }
                    else {
                        expec = NULL;
                    }
                    test_assert(expec == res, FAILURE_MSG2);

                    set_priors(test_buf, wsize, 0xffffffff, j, inc);
                }

                memset_c(test_buf + j, 0xff, wsize);
                memset_c(test_buf + k, 0x0, wsize);


                test_assert(run(test_buf, 0x01010101) == NULL, FAILURE_MSG);
                res = run(test_buf, 0xffffffff);
                if (k) {
                    expec = test_buf + k - wsize;
                }
                else {
                    expec = NULL;
                }
                test_assert(res == expec, FAILURE_MSG);

                test_assert(run(test_buf, 0x0) == test_buf + k, FAILURE_MSG);
                memset_c(test_buf + k, 0xff, wsize);
            }
        }
    }
    return 0;
}

static int
test_strrchr_driver(void const * test_f, const uint32_t wsize) {
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += 2048 + 4) {
        if (i == PAGE_SIZE) {
        }
        if (test_strrchr_kernel(test_f, wsize, i)) {

            return 1;
        }
    }
    return 0;
}

int
test_strrchr(void const * test_f) {
    return test_strrchr_driver(test_f, 1);
}
int
test_wcsrchr(void const * test_f) {
    return test_strrchr_driver(test_f, 4);
}
