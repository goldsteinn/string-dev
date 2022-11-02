#ifndef _SRC__STRING_TEST_CPY_COMMON_H_
#define _SRC__STRING_TEST_CPY_COMMON_H_

#include <immintrin.h>
#include <stdint.h>
#include <string.h>

#define GET_EXPEC(addr, idx) (uint8_t)(((((uint64_t)(addr)) + (idx)) % 254) + 1)
#define PTR_MOD(addr, m)     (((uint64_t)(addr)) % (m))
enum { START = 1, END = 0 };


static int32_t
check_region_is(uint8_t const * s, uint8_t v, uint64_t len) {
    uint64_t i = 0;
    for (; i < len && PTR_MOD(s + i, 32); ++i) {
        if (s[i] != v) {
            return 1;
        }
    }
    if (i + 32 < len) {
        __m256i vec = _mm256_set1_epi8(v);
        for (; i + 32 < len; i += 32) {
            uint32_t res = _mm256_movemask_epi8(_mm256_cmpeq_epi8(
                _mm256_loadu_si256((__m256i const *)(s + i)), vec));
            if (res != 0xffffffff) {
                return 1;
            }
        }
    }
    for (; i < len; ++i) {
        if (s[i] != v) {
            return 1;
        }
    }

    return 0;
}

static void
init_sentinel(uint8_t * start, uint8_t * end, int32_t start_or_end) {
    die_assert(start <= end);
    __m256i v = _mm256_set1_epi8(-1);
    if ((start + 32 <= end) == start_or_end) {
        _mm256_storeu_si256((__m256i *)(end - 32), v);
    }
    else {
        _mm256_storeu_si256((__m256i *)start, v);
    }
}


static int32_t
check_region(const uint8_t * s1, const uint8_t * s2, uint64_t len) {
    for (uint64_t i = 0; i < len; ++i) {
        if (s1[i] != GET_EXPEC(s2, i)) {
            fprintf(stderr, "(%p, %p): %lu / %lu: %x != %x\n", s1 + i, s2 + i,
                    i, len, s1[i], GET_EXPEC(s2, i));
            return 1;
        }
    }
    return memcmp(s1, s2, len);
}

static int32_t
check_sentinel(const uint8_t * start, const uint8_t * end, int start_or_end) {
    assert(start <= end);
    __m256i  boundary_v = _mm256_set1_epi8(-1);
    uint32_t expec      = (start + 32 <= end) ? ~0u : (1u << (end - start)) - 1;
    uint32_t shift      = (start + 32 <= end) || (start_or_end == START)
                              ? 0
                              : (start - (end - 32));
    if ((start + 32 <= end) == start_or_end) {
        PRINTFFL;
        __m256i v = _mm256_loadu_si256((__m256i const *)(end - 32));
        return ((_mm256_movemask_epi8(_mm256_cmpeq_epi8(v, boundary_v)) >>
                 shift) &
                expec) != expec;
    }
    else {
        PRINTFFL;
        __m256i v = _mm256_loadu_si256((__m256i const *)start);
        return ((_mm256_movemask_epi8(_mm256_cmpeq_epi8(v, boundary_v)) >>
                 shift) &
                expec) != expec;
    }
}


static void
init_region(uint8_t * s2, uint64_t len) {
    for (uint64_t i = 0; i < len; ++i) {
        s2[i] = GET_EXPEC(s2, i);
        assert(s2[i] != 0);
        assert(s2[i] < 255);
    }
}

static void
init_cpy_sentinels(uint8_t * s1_start,
                   uint8_t * s1_end,
                   uint8_t * s1,
                   uint64_t  len) {
    init_sentinel(s1_start, s1, START);
    init_sentinel(s1 + len, s1_end, END);
}

static void
init_cpy_dst(uint8_t * s1_start, uint8_t * s1_end, uint8_t * s1, uint64_t len) {
    memset_c(s1, 0xff, len);
    init_cpy_sentinels(s1_start, s1_end, s1, len);
}


static int32_t
check_cpy(const uint8_t * s1_start,
          const uint8_t * s1_end,
          const uint8_t * s1,
          const uint8_t * s2,
          uint64_t        len) {

    if (check_sentinel(s1_start, s1, START)) {
        fprintf(stderr, "Start Sentinel Error\n");
        return 1;
    }
    if (check_region(s1, s2, len)) {
        fprintf(stderr, "Region Error: %lu\n", len);
        return 2;
    }
    if (check_sentinel(s1 + len, s1_end, END)) {
        fprintf(stderr, "End Sentinel Error\n");
        return 3;
    }
    return 0;
}

#endif
