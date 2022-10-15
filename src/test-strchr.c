#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"

#define run(s, c)                                                              \
    CAST(uint8_t *,                                                            \
         wsize == 4                                                            \
             ? CAST(uint8_t *, func.run_wcschr(CAST(wchar_t const *, s),       \
                                               CAST(wchar_t, c)))              \
             : CAST(uint8_t *, func.run_strchr(CAST(char const *, s), c)))

static uint8_t *
get_strchr_expec(uint8_t * s, uint64_t pos, uint64_t len) {
    return pos < len ? (s + pos) : NULL;
}


static uint8_t *
get_strchrnul_expec(uint8_t * s, uint64_t pos, uint64_t len) {
    return pos < len ? (s + pos) : (s + len);
}

typedef FUNC_T(get_strchr_expec) expec_f;

#define INIT_I 0
#define INIT_J 0
#define INIT_K 0
#define FAILURE_MSG                                                            \
    "%p != %p, align=%u(%u), pos=%u, len=%u\n", res, expec, i, al_offset, j, k

//#define PRINTV(...) fprintf(stderr, __VA_ARGS__)

#ifndef PRINTV
#define PRINTV(...)
#endif

static int
test_strchr_kernel(void const * test_f,
                   uint32_t     wsize,
                   expec_f      get_expec,
                   uint64_t     test_size) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    uint8_t *     test_buf;
    test_size                 = ROUNDDOWN_P2(test_size, wsize);
    memset_c(buf, 0xff, test_size);
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = ROUNDUP_P2(alignments[i % nalignments], wsize);
        fprintf(stderr, "%u\n", i);
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        if (al_offset > test_size) {
            continue;
        }

        test_buf = buf + al_offset;

        uint32_t test_max = test_size - al_offset;
        for (uint32_t j = INIT_J; j < test_max; j += wsize) {
            for (uint32_t k = INIT_K; k < MIN(test_max, j + 320);
                 k          = ROUNDUP_P2(next_v(k, test_size), wsize)) {
                uint8_t *res, *expec;
                PRINTV("%u:%u:%u\n", i, j, k);
                memset(test_buf + j, 0x01, wsize);
                memset(test_buf + k, 0x00, wsize);

                expec = get_expec(test_buf, j, k);
                res   = run(test_buf, 0x01010101);

                test_assert(res == expec, FAILURE_MSG);

                memset(test_buf + j, 0xff, wsize);
                memset(test_buf + k, 0xff, wsize);
            }
        }
    }
    return 0;
}

static int
test_strchr_driver(void const * test_f, uint32_t wsize, expec_f get_expec) {
    for (uint32_t i = PAGE_SIZE; i <= PAGE_SIZE * 2; i += PAGE_SIZE) {
        if (test_strchr_kernel(test_f, wsize, get_expec, i)) {
            return 1;
        }
    }
    return 0;
}

int
test_strchr(void const * test_f) {
    return test_strchr_driver(test_f, 1, &get_strchr_expec);
}

int
test_wcschr(void const * test_f) {
    return test_strchr_driver(test_f, 4, &get_strchr_expec);
}

int
test_strchrnul(void const * test_f) {
    return test_strchr_driver(test_f, 1, &get_strchrnul_expec);
}
