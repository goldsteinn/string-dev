#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"
#include "util/error-util.h"
#if 1
#define run(s, n)                                                              \
    (wsize == 4 ? (maxlen ? func.run_wcsnlen(CAST(wchar_t const *, s), (n))    \
                          : func.run_wcslen(CAST(wchar_t const *, s)))         \
                : (maxlen ? func.run_strnlen(CAST(char const *, s), (n))       \
                          : func.run_strlen(CAST(char const *, s))))
#else
static size_t simple_strnlen(uint8_t const * s, size_t n) {
    size_t i = 0;
    for(;;) {
        if(i >= n) {
            goto done;
        }
        if(s[i] == 0) {
            goto done;
        }
        ++i;
    }
done:
    return i;
}

#define run(s, n) simple_strnlen(s, n)
#endif
#define INIT_I 0
#define INIT_J 320
#define INIT_K 325

#define TEST_ERR                                                               \
    "(%zu != %zu): align=%zu, strlen=%zu, maxlen=%zu, wsize=%zu\n", res,       \
        expec, i, j, k, wsize

static int32_t
test_strlen_kernel(void const * test_f,
                   uint64_t     test_size,
                   uint64_t     maxlen,
                   uint64_t     wsize) {
    func_switch_t func = { test_f };
    (void)(func);
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    uint64_t      i, j, k;
    uint64_t      wsize_shift = wsize == 4 ? 2 : 0;
    die_assert(wsize == 1 || wsize == 4);

    memset_c(buf, 0x1, test_size);

    for (i = INIT_I; i < nalignments * 2; ++i) {
        uint64_t al_offset = ROUNDUP_P2(alignments[i % nalignments], wsize);
        fprintf(stderr, "%lu\n", i);
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }

        uint64_t test_max = test_size - al_offset;
        test_buf          = buf + al_offset;
        for (j = INIT_J; j < test_max; j += wsize) {
            uint64_t res, expec;
            memset_c(test_buf + j, 0x0, wsize);
            for (k = INIT_K; k < MIN(test_max, j + 320); k += wsize) {
                //                fprintf(stderr, "%lu:%lu:%lu\n", i, j, k);
                expec = j;
                if (maxlen && k < j) {
                    expec = k;
                }
                expec >>= wsize_shift;

                res = run(test_buf, k >> wsize_shift);

                test_assert(expec == res, TEST_ERR);
                if (!maxlen) {
                    break;
                }
                memset_c(test_buf + j, 0x1, wsize);
                expec = k >> wsize_shift;

                res = run(test_buf, k >> wsize_shift);

                test_assert(expec == res, TEST_ERR);
                memset_c(test_buf + j, 0x0, wsize);
            }

            if (maxlen) {
                expec = j >> wsize_shift;
                k     = -1UL;
                res   = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);


                k     = -63UL;
                res   = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);

                k     = -64UL;
                res   = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);

                k     = -65UL;
                res   = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);                                

                
                k   = 1UL << 63;
                res = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);

                k   = 1UL << 62;
                res = run(test_buf, k);
                test_assert(expec == res, TEST_ERR);
            }

            memset_c(test_buf + j, 0x1, wsize);
            if (j + 128 < test_max) {
                memset_c(test_buf + j + 128, 0x1, wsize);
            }
        }
    }
    return 0;
}

int32_t
test_strlen(void const * test_f) {
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE, 0, 1) == 0);
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE * 2, 0, 1) == 0);
    return 0;
}

int32_t
test_strnlen(void const * test_f) {
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE, 1, 1) == 0);
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE * 2, 1, 1) == 0);
    return 0;
}

int32_t
test_wcslen(void const * test_f) {
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE, 0, 4) == 0);
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE * 2, 0, 4) == 0);
    return 0;
}

int32_t
test_wcsnlen(void const * test_f) {
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE, 1, 4) == 0);
    test_assert(test_strlen_kernel(test_f, PAGE_SIZE * 2, 1, 4) == 0);
    return 0;
}
