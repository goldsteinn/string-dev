#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"


#define run(s, c, n)                                                           \
    CAST(uint8_t *, func.run_memrchr(CAST(char const *, s), c, n))


static void
set_priors(uint8_t * buf, uint32_t setv, uint32_t ub, uint32_t inc) {
    for (uint32_t m = 0; m < ub; m += inc) {
        __builtin_memcpy(buf + m, &setv, 1);
    }
}

#define INIT_I   0
#define INIT_J   0
#define INIT_K   0
#define INIT_INC 12

#define FAILURE_MSG                                                            \
    "%p != %p, align=%u(%u), pos=%u, len=%u\n", res, expec, i, al_offset, j, k

#define FAILURE_MSG2                                                           \
    "%p != %p, align=%u(%u), pos=%u, len=%u, inc=%u\n", res, expec, i,         \
        al_offset, j, k, inc

static int
test_memrchr_kernel(void const * test_f, uint32_t test_size) {
    if (test_size <= 4096) {
        return 0;
    }
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    memset_c(buf, 0xff, test_size);
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = alignments[i % nalignments];
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }
        fprintf(stderr, "%u\n", i);
        uint32_t test_max = test_size - al_offset;
        for (uint32_t j = INIT_J; j < test_max;
             j          = j < 512 ? j + 1 : next_v(j, test_size)) {
            for (uint32_t k = INIT_K; k < MIN(test_max, j + 512);
                 k          = k < 512 ? k + 1 : next_v(k, test_size)) {
                test_buf = buf + al_offset;
                uint8_t *res, *expec;

                expec = NULL;
                res   = run(test_buf, 0x01, k);
                test_assert(res == NULL, FAILURE_MSG);

                if (k + 1 < test_max) {
                    memset_c(test_buf + k + 1, 0x01, 1);

                    res = run(test_buf, 0x01, k);
                    test_assert(res == expec, FAILURE_MSG);

                    memset_c(test_buf + k + 1, 0xf1, 1);
                }

                memset_c(test_buf + j, 0x01, 1);

                expec = (j >= k ? NULL : test_buf + j);
                res   = run(test_buf, 0x01, k);
                test_assert(res == expec, FAILURE_MSG);

                if (k + 1 < test_max && k + 1 != j) {
                    memset_c(test_buf + k + 1, 0x01, 1);

                    res = run(test_buf, 0x01, k);
                    test_assert(res == expec, FAILURE_MSG);

                    memset_c(test_buf + k + 1, 0xf1, 1);
                }

                if (test_buf != buf) {
                    memset_c(test_buf - 1, 0x01, 1);

                    res = run(test_buf, 0x01, k);
                    test_assert(res == expec, FAILURE_MSG);

                    memset_c(test_buf - 1, 0xf1, 1);
                }

                if (expec && 0) {
                    res = run(CAST(uint8_t *, 1UL), 0x01,
                              CAST(uint64_t, test_buf + k - 1));
                    test_assert(res == expec, FAILURE_MSG);
                }

                for (uint32_t inc = INIT_INC ? INIT_INC : 12; 1 && inc < 128;
                     inc += 12) {
                    set_priors(test_buf, 0x01, j, inc);
                    if (!k) {
                        expec = NULL;
                    }
                    else if (j >= k) {
                        expec = test_buf + (k - ((k - 1) % inc) - 1);
                    }
                    else {
                        expec = test_buf + j;
                    }

                    res = run(test_buf, 0x01, k);
                    test_assert(res == expec, FAILURE_MSG2);
                    if (expec && 0) {
                        res = run((test_buf - (1UL << 63)), 0x01,
                                  k + (1UL << 63));
                        test_assert(res == expec, FAILURE_MSG2);
                    }
                    set_priors(test_buf, 0xff, j, inc);
                }
                memset_c(test_buf + j, 0xf1, 1);
            }
        }
    }
    return 0;
}

int
test_memrchr(void const * test_f) {
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += 2048 + 4) {
        if (i == PAGE_SIZE) {
        }
        if (test_memrchr_kernel(test_f, i)) {

            return 1;
        }
    }
    return 0;
}
