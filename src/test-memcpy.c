#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"
#include "string-test-cpy-common.h"

#define run(d, s, n)                                                           \
    CAST(uint8_t *, func.run_memcpy(CAST(void *, d), CAST(void const *, s), n))


static int32_t
check_region_mm(const uint8_t * s1, const uint8_t * s2, uint64_t len) {
    return memcmp(s1, s2, len);
}

static void
init_memcpy_dst(uint8_t * s1_start,
                uint8_t * s1_end,
                uint8_t * s1,
                uint64_t  len) {
    init_cpy_dst(s1_start, s1_end, s1, len);
}

static void
init_memcpy_sentinels(uint8_t * s1_start,
                      uint8_t * s1_end,
                      uint8_t * s1,
                      uint64_t  len) {
    init_cpy_sentinels(s1_start, s1_end, s1, len);
}

static int32_t
check_memcpy(const uint8_t * s1_start,
             const uint8_t * s1_end,
             const uint8_t * s1,
             const uint8_t * s2,
             uint64_t        len) {
    return check_cpy(s1_start, s1_end, s1, s2, len);
}

static int32_t
check_memmove(const uint8_t * s1_start,
              const uint8_t * s1_end,
              const uint8_t * s1,
              const uint8_t * s2_tmp,
              uint64_t        len) {
    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }
    if (check_region_mm(s1, s2_tmp, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        for (uint32_t i = 0; i < len; ++i) {
            uint32_t tmp = s1[i] == s2_tmp[i];
            fprintf(stderr, "%u: %x vs %x --> %d\n", i, s1[i], s2_tmp[i], tmp);
            if (!tmp) {
                break;
            }
        }
        return 2;
    }
    if (check_sentinel(s1 + len, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }
    (void)(s1_start);
    (void)(s1_end);
    return 0;
}


static void
init_memmove(uint8_t * s1_start,
             uint8_t * s1_end,
             uint8_t * s1,
             uint8_t * s2_tmp,
             uint8_t * s2,
             uint64_t  len) {
    init_region(s2, len);
    init_sentinel(s1_start, s1, START);
    init_sentinel(s1 + len, s1_end, END);
    memcpy(s2_tmp, s2, len);

    (void)(s1_start);
    (void)(s1_end);
    (void)(s1);
}


#define FAILURE_MSG                                                            \
    "%lu, %lu, %u, %u, %u\n", ((uint64_t)test1) % 4096,                        \
        ((uint64_t)test2) % 4096, i, j, k
#define INIT_I 0
#define INIT_J 0
#define INIT_K 0
//#define PRINTV(...) fprintf(stderr, __VA_ARGS__)
#ifndef PRINTV
#define PRINTV(...)
#endif
static int
test_memcpy_kernel_overlap(void const * test_f,
                           uint32_t     test_min,
                           uint32_t     test_size) {
    func_switch_t func = { test_f };

    uint8_t * s_base = make_buf(test_size);
    uint8_t * s_tmp  = make_buf(test_size);

    init_region(s_base, test_size);
    init_region(s_tmp, test_size);
    uint8_t *test1, *test2;
    uint64_t al_pairs[NPAIRS * 2] = { 0 };
    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        fprintf(stderr, "%u\n", i);
        uint32_t al_offset = alignments[i % nalignments];
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        make_alignment_pairs(al_pairs, al_offset);
        for (uint32_t j = MAX((uint32_t)INIT_J, test_min);
             j + al_offset < test_size; ++j) {

            for (uint32_t k = INIT_K; k < NPAIRS; ++k) {
                PRINTV("%u:%u:%u\n", al_offset, j, k);
                test1 = s_base + al_pairs[S1_IDX(k)];
                test2 = s_base + al_pairs[S2_IDX(k)];

                init_memmove(s_base, s_base + test_size, test1, s_tmp, test2,
                             j);
                run(test1, test2, j);
                test_assert(check_memmove(s_base, s_base + test_size, test1,
                                          s_tmp, j) == 0);

                test1 = s_base + al_pairs[S1_IDX(k)];
                test2 = s_base + ((test_size - j) - 0);

                init_memmove(s_base, s_base + test_size, test1, s_tmp, test2,
                             j);
                run(test1, test2, j);
                test_assert(check_memmove(s_base, s_base + test_size, test1,
                                          s_tmp, j) == 0);
            }
        }
    }
    return 0;
}

static int
test_memcpy_kernel_no_overlap(void const * test_f,
                              uint32_t     test_min,
                              uint32_t     test_size) {
    func_switch_t func  = { test_f };
    uint8_t *     s1    = make_buf(test_size);
    uint8_t *     s2_lo = make_buf(test_size);
    uint8_t *     s2_hi = make_buf(test_size);
    {
        uint8_t * tmp;
        if (s2_lo > s1) {
            tmp   = s1;
            s1    = s2_lo;
            s2_lo = tmp;
        }
        if (s1 > s2_hi) {
            tmp   = s1;
            s1    = s2_hi;
            s2_hi = tmp;
            if (s2_lo > s1) {
                tmp   = s1;
                s1    = s2_lo;
                s2_lo = tmp;
            }
        }
    }
    init_region(s1, test_size);
    init_region(s2_lo, test_size);
    init_region(s2_hi, test_size);

    uint8_t *test1, *test2;
    uint64_t al_pairs[NPAIRS * 2] = { 0 };

    for (uint32_t i = INIT_I; i < nalignments * 2; ++i) {
        uint32_t al_offset = alignments[i % nalignments];
        al_offset = (i >= nalignments ? PAGE_SIZE - al_offset : al_offset);
        make_alignment_pairs(al_pairs, al_offset);
        fprintf(stderr, "%u\n", i);
        for (uint32_t j = MAX((uint32_t)INIT_J, test_min);
             j + al_offset < test_size; ++j) {
            // fprintf(stderr, "%u\n", j);
            for (uint32_t k = INIT_K; k < NPAIRS; ++k) {
                PRINTV("%u:%u:%u\n", al_offset, j, k);
                test1 = s1 + al_pairs[S1_IDX(k)];
                test2 = s2_lo + al_pairs[S2_IDX(k)];

                init_memcpy_dst(s1, s1 + test_size, test1, j);
                run(test1, test2, j);
                test_assert(
                    check_memcpy(s1, s1 + test_size, test1, test2, j) == 0,
                    FAILURE_MSG);

                test1 = s1 + al_pairs[S1_IDX(k)];
                test2 = s2_hi + al_pairs[S2_IDX(k)];

                init_memcpy_dst(s1, s1 + test_size, test1, j);
                run(test1, test2, j);
                test_assert(
                    check_memcpy(s1, s1 + test_size, test1, test2, j) == 0,
                    FAILURE_MSG);
            }
        }
    }
    return 0;
}

int
test_memcpy(void const * test_f) {
    test_assert(test_memcpy_kernel_overlap(test_f, 0, PAGE_SIZE * 2) == 0);
    test_assert(test_memcpy_kernel_overlap(test_f, 262144 - 80, 262144 + 512) ==
                0);
    test_assert(test_memcpy_kernel_no_overlap(test_f, 0, PAGE_SIZE * 2) == 0);
    test_assert(
        test_memcpy_kernel_no_overlap(test_f, 262144 - 80, 262144 + 512) == 0);

    return 0;
}
