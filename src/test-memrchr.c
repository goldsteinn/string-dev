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

//#define PRINTV(...) fprintf(stderr, __VA_ARGS__)
#ifndef PRINTV
#define PRINTV(...)
#endif

#define FAILURE_MSG                                                            \
    "%p != %p, align=%u(%u), pos=%u, len=%u\n", res, expec, i, al_offset, j, k

#define FAILURE_MSG3                                                            \
    "%p != %p, %u: i=%u, pos=%u, len=%u\n", res, expec, test_size, i, j, k

#define FAILURE_MSG2                                                           \
    "%p != %p, align=%u(%u), pos=%u, len=%u, inc=%u\n", res, expec, i,         \
        al_offset, j, k, inc

static int
test_memrchr_kernel_robust(void const * test_f, uint32_t test_size) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     res, *expec;
    memset_c(buf, 0xff, test_size);
    uint32_t k;
    for (uint32_t i = INIT_I; i < test_size; ++i) {
        for (uint32_t j = INIT_J; j + i < test_size; ++j) {
            for (k = 0; k < 64 && k + i + j < test_size; k += 8) {
                buf[i + j + k] = 0x1;
            }
            test_assert(run(buf + i, 0x01, j) == NULL);
            if (j) {
                *(buf + i) = 0x01;
                res        = run(buf + i, 0x01, j);
                expec      = buf + i;
                test_assert(res == expec, FAILURE_MSG3);
                *(buf + i) = 0xff;
            }
            if (i) {
                *(buf + i - 1) = 0x01;
                assert(run(buf + i, 0x01, j) == NULL);
                *(buf + i - 1) = 0xff;
            }
            if (j >= 32) {
                *(buf + i + j - 1) = 0x01;
                assert(run(buf + i, 0x01, j) == (buf + i + j - 1));
                *(buf + i + j - 17) = 0x01;
                assert(run(buf + i, 0x01, j) == (buf + i + j - 1));


                *(buf + i + j - 1) = 0xff;
                assert(run(buf + i, 0x01, j) == (buf + i + j - 17));
                *(buf + i + j - 17) = 0xff;

                *(buf + i + j - 31) = 0x01;
                assert(run(buf + i, 0x01, j) == (buf + i + j - 31));
                *(buf + i + j - 31) = 0xff;
            }
            for (uint32_t k = 0; k < 64 && k + i + j < test_size; k += 8) {
                buf[i + j + k] = 0xff;
            }
        }
    }
    free_buf(buf, test_size);
    return 0;
}

static int
test_memrchr_kernel(void const * test_f, uint32_t test_size) {
    if (test_size < 4096) {
        return 0;
    }
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    memset_c(buf, 0xff, test_size);

    uint8_t * of_buf = buf + 2048;
    uint64_t  of_len = -1024UL;
    __asm__ volatile("" : "+r"(of_len) : :);
    memset(buf, 0x1, 1);

    //    test_assert(run(of_buf, 0x1, of_len) == buf);
    (void)(of_buf);
    memset(buf, 0xff, 1);

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
                PRINTV("%u:%u:%u\n", i, j, k);
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
    free_buf(buf, test_size);
    return 0;
}

int
test_memrchr(void const * test_f) {
    for (uint32_t i = PAGE_SIZE * 1; i <= 2 * PAGE_SIZE; i += PAGE_SIZE) {
        if (test_memrchr_kernel(test_f, i)) {
            return 1;
        }
    }
    
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += PAGE_SIZE) {
        if (test_memrchr_kernel_robust(test_f, i)) {
            return 1;
        }
    }


    return 0;
}
