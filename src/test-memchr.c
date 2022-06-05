#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"


#define run(s, c, n)                                                           \
    CAST(uint8_t *,                                                            \
         (wsize == 4)                                                          \
             ? CAST(uint8_t *,                                                 \
                    func.run_wmemchr(CAST(wchar_t const *, s), c, (n) / 4))    \
             : CAST(uint8_t *,                                                 \
                    (with_len ? CAST(uint8_t *,                                \
                                     func.run_memchr(CAST(char const *, s),    \
                                                     CAST(uint8_t, c), n))     \
                              : CAST(uint8_t *,                                \
                                     func.run_rawmemchr(CAST(char const *, s), \
                                                        CAST(uint8_t, c))))))


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
test_memchr_kernel(void const * test_f,
                   uint32_t     test_size,
                   uint32_t     wsize,
                   int          with_len) {
    if (test_size <= 4096) {
        return 0;
    }
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    memset_c(buf, 0xff, test_size);
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = alignments[i % nalignments];
        al_offset          = ROUNDUP_P2(
                     (i >= nalignments ? PAGE_SIZE - al_offset : al_offset), wsize);

        if (al_offset > test_size) {
            continue;
        }
        fprintf(stderr, "%u\n", i);
        uint32_t test_max = test_size - al_offset;
        for (uint32_t j = INIT_J; j < test_max;
             j          = j < 512 ? j + wsize
                                  : ROUNDUP_P2(next_v(j, test_size), wsize)) {
            for (uint32_t k = INIT_K; k < MIN(test_max, j + 512);
                 k          = k < 512 ? k + wsize
                                      : ROUNDUP_P2(next_v(k, test_size), wsize)) {
                uint8_t *res, *expec;
                test_buf = buf + al_offset;


                assert(k % wsize == 0);
                assert(j % wsize == 0);
                assert(CAST(uint64_t, test_buf) % wsize == 0);

                if (with_len) {
                    expec = NULL;
                    res   = run(test_buf, 0x01010101, k);
                    test_assert(res == NULL, FAILURE_MSG);

                    if (k + wsize < test_max) {
                        memset_c(test_buf + k + wsize, 0x01, wsize);

                        res = run(test_buf, 0x01010101, k);
                        test_assert(res == expec, FAILURE_MSG);

                        memset_c(test_buf + k + wsize, 0xff, wsize);
                    }
                }

                memset_c(test_buf + j, 0x01, wsize);

                expec = (with_len && j >= k) ? NULL : test_buf + j;
                res   = run(test_buf, 0x01010101, k);
                test_assert(res == expec, FAILURE_MSG);


                memset_c(test_buf + j, 0xff, wsize);

                if (!with_len) {
                    break;
                }
            }
        }
    }
    return 0;
}

int
test_memchr(void const * test_f) {
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += 2048 + 4) {
        if (i == PAGE_SIZE) {
        }
        if (test_memchr_kernel(test_f, i, 1, 1)) {

            return 1;
        }
    }
    return 0;
}


int
test_rawmemchr(void const * test_f) {
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += 2048 + 4) {
        if (i == PAGE_SIZE) {
        }
        if (test_memchr_kernel(test_f, i, 1, 0)) {

            return 1;
        }
    }
    return 0;
}

int
test_wmemchr(void const * test_f) {
    for (uint32_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += 2048 + 4) {
        if (i == PAGE_SIZE) {
        }
        if (test_memchr_kernel(test_f, i, 4, 1)) {

            return 1;
        }
    }
    return 0;
}
