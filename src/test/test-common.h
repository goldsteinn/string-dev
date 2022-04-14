#ifndef _SRC__TEST__TEST_COMMON_H_
#define _SRC__TEST__TEST_COMMON_H_

#include "util/attrs.h"
#include "util/common.h"
#include "util/macro.h"
#include "util/memory-util.h"
#include "util/random.h"
#include "util/types.h"

static MALLOC_FUNC uint8_t *
                   make_buf(uint64_t sz) {
    uint8_t * buf =
        CAST(uint8_t *, safe_mmap(NULL, 2 * PAGE_SIZE + sz, PROT_NONE,
                                  MAP_ANONYMOUS | MAP_PRIVATE, -1, 0));
    safe_mprotect(buf + PAGE_SIZE, sz, PROT_READ | PROT_WRITE);
    return buf + PAGE_SIZE;
}


static NONNULL(1) void free_buf(uint8_t * buf, uint64_t sz) {
    safe_munmap(buf - PAGE_SIZE, sz + 2 * PAGE_SIZE);
}


static NONNULL(1) void randomize_buf(uint8_t * buf, uint64_t sz) {
    uint64_t i;
    uint64_t aligned_sz = sz & (-sizeof(uint64_t));
    for (i = 0; i < aligned_sz; i += sizeof(uint64_t)) {
        uint64_t v = rand64();
        __builtin_memcpy(buf + i, &v, sizeof(uint64_t));
    }
    for (; i < sz; ++i) {
        uint8_t v = CAST(uint8_t, rand32());
        buf[i]    = v;
    }
}

static NONNULL(1) void seq_buf(uint8_t * buf, uint64_t sz) {
    for (uint64_t i = 0; i < sz; ++i) {
        buf[i] = CAST(uint8_t, i);
    }
}

static NONNULL(1) int32_t is_seq(uint8_t const * buf, uint64_t sz) {
    for (uint64_t i = 0; i < sz; ++i) {
        uint8_t bufi = buf[i];
        if (bufi != CAST(uint8_t, i)) {
            return 0;
        }
    }
    return 1;
}

#define PRINTLN fprintf(stderr, "%-20s:%-4u\n", __FILENAME__, __LINE__)
#define test_assert(...)                                                       \
    CAT(test_assert_, NOT_ONE_NARG(__VA_ARGS__))(__VA_ARGS__)
#define _test_assert(X, todo)                                                  \
    if (UNLIKELY(!(X))) {                                                      \
        fprintf(stderr, "\n\t%-20s:%-4u", __FILENAME__, __LINE__);             \
        todo;                                                                  \
        abort();                                                               \
        return -1;                                                             \
    }

#define test_assert_MANY(X, msg, args...)                                      \
    _test_assert(X, fprintf(stderr, "\t" msg "\n", ##args));

#define test_assert_ONE(X) _test_assert(X, fprintf(stderr, "\n"))


#endif
