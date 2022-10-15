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
#define INIT_J   264
#define INIT_K   385
#define INIT_INC 12
//#define PRINTV(...) fprintf(stderr, __VA_ARGS__)


#define FAILURE_MSG                                                            \
    "%p != %p, align=%lu(%lu), pos=%lu, len=%lu\n", res, expec, i, al_offset,  \
        j, k

#define FAILURE_MSG2                                                           \
    "%p != %p, align=%lu(%lu), pos=%lu, len=%lu, inc=%lu\n", res, expec, i,    \
        al_offset, j, k, inc


#ifndef PRINTV
#define PRINTV(...)
#endif

extern char * rawmemchr_avx2_dev(char const *, char);

void
bad_rawmemchr() {
    char * buf = mmap(0, 8192, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(buf != MAP_FAILED);
    memset(buf, -1, 8192);


    char * ptr_start = buf + 4096 - 8;


    /* Out of range matches. */
    memset(ptr_start - 8, 0x1, 8);

    ptr_start[32] = 0x1;


    /* Fails. */
    assert(rawmemchr_avx2_dev(ptr_start, 0x1) == ptr_start + 32);
}

static int
test_rawmemchr_kernel(void const * test_f, uint64_t test_size) {
    bad_rawmemchr();
    func_switch_t func = { test_f };
    (void)(func);
    uint8_t * buf = make_buf(test_size);
    memset_c(buf, 0xff, test_size);
    for (uint64_t i = 0; i < test_size; ++i) {
        for (uint64_t j = 0; j + i < test_size; ++j) {
            for (uint64_t k = 1; k <= 32 && k < i; ++k) {
                buf[i - k] = 0x1;
            }
            buf[i + j] = 0x1;
            uint8_t * res =
                CAST(uint8_t *, func.run_rawmemchr(CAST(char const *, buf + i),
                                                   CAST(uint8_t, 0x1)));

            test_assert(res == buf + i + j);
            buf[i + j] = 0xff;
            for (uint64_t k = 1; k <= 32 && k < i; ++k) {
                buf[i - k] = 0xff;
            }
        }
    }
    return 0;
}

static int
test_memchr_kernel(void const * test_f,
                   uint64_t     test_size,
                   uint64_t     wsize,
                   int          with_len) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    memset_c(buf, 0xff, test_size);
    for (uint64_t i = INIT_I; i < nalignments * 2; ++i) {
        uint64_t al_offset = alignments[i % nalignments];
        al_offset          = ROUNDUP_P2(
                     (i >= nalignments ? PAGE_SIZE - al_offset : al_offset), wsize);

        if (al_offset > test_size) {
            continue;
        }
        fprintf(stderr, "%lu\n", i);
        uint64_t test_max = test_size - al_offset;
        for (uint64_t j = INIT_J; j < test_max;
             j          = j < 1400 ? j + wsize
                                   : ROUNDUP_P2(next_v(j, test_size), wsize)) {
            uint8_t *res, *expec;
            for (uint64_t k = INIT_K; k < MIN(test_max, j + 1024);
                 k          = k < 1400 ? k + wsize
                                       : ROUNDUP_P2(next_v(k, test_size), wsize)) {
                PRINTV("%lu:%lu:%lu\n", i, j, k);
                test_buf = buf + al_offset;

                PRINTFFL;
                assert(al_offset % wsize == 0);
                assert(k % wsize == 0);
                assert(j % wsize == 0);
                assert(CAST(uint64_t, test_buf) % wsize == 0);
                PRINTFFL;

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
                PRINTFFL;
                memset_c(test_buf + j, 0x01, wsize);
                PRINTFFL;
                expec = (with_len && j >= k) ? NULL : (test_buf + j);
                res   = run(test_buf, 0x01010101, k);
                test_assert(res == expec, FAILURE_MSG);
                PRINTFFL;
                memset_c(test_buf + j, 0xff, wsize);
                PRINTFFL;
                if (with_len) {
                    test_assert(run(test_buf, 0x01010101, k) == NULL);
                }
                else {
                    break;
                }
            }

            PRINTFFL;
            if (with_len) {
                PRINTFFL;
                uint64_t k;
                test_buf = buf + al_offset;
                memset_c(test_buf + j, 0x01, wsize);
                PRINTFFL;
                expec = test_buf + j;
                k     = -1UL;
                res   = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;

                k   = -63UL;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = -64UL;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = -65UL;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;

                k   = 1UL << 63;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = 1UL << 62;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = 1UL << 32;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = (1UL << 32) - 1;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = (1UL << 63) | (1UL << 62);
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);
                PRINTFFL;
                k   = (1UL << 63) | (1UL << 62) | 1;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);


                k   = (uint64_t)test_buf;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);

                k   = -(uint64_t)test_buf;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);

                k   = 1UL - (uint64_t)test_buf;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);

                k   = -1UL - (uint64_t)test_buf;
                res = run(test_buf, 0x01010101, k);
                test_assert(expec == res, FAILURE_MSG);

                memset_c(test_buf + j, 0xff, wsize);
                PRINTFFL;
            }
            PRINTFFL;
        }
    }
    return 0;
}

int
test_memchr(void const * test_f) {
    for (uint64_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += PAGE_SIZE) {

        if (test_memchr_kernel(test_f, i, 1, 1)) {

            return 1;
        }
    }
    return 0;
}


int
test_rawmemchr(void const * test_f) {
    for (uint64_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += PAGE_SIZE) {

        if (test_memchr_kernel(test_f, i, 1, 0)) {
            return 1;
        }
        if (test_rawmemchr_kernel(test_f, i)) {
            return 1;
        }
    }
    return 0;
}

int
test_wmemchr(void const * test_f) {
    for (uint64_t i = PAGE_SIZE; i <= 2 * PAGE_SIZE; i += PAGE_SIZE) {
        if (test_memchr_kernel(test_f, i, 4, 1)) {

            return 1;
        }
    }
    return 0;
}
