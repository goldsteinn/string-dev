#include "test/test-common.h"
#include "util/common.h"
#include "util/inline-math.h"

#include "string-func-switches.h"
#include "string-test-common.h"
#define run(s, c, n) CAST(uint8_t *, func.run_memset(s, c, n))


#define FILL (0xff)
#define VAL  (0x01)
static int
region_good(uint8_t const * buf,
            uint64_t        start,
            uint64_t        sz,
            uint64_t        test_size) {
    uint64_t i = 0;
    for (; i < start; ++i) {
        if (buf[i] != FILL) {
            return 1;
        }
    }
    for (; i < start + sz; ++i) {
        if (buf[i] != VAL) {
            return 1;
        }
    }
    for (; i < test_size; ++i) {
        if (buf[i] != FILL) {
            return 1;
        }
    }

    return 0;
}


static int
test_memset_kernel(void const * test_f, uint32_t test_size) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf(test_size);
    memset(buf, FILL, test_size);


    for (uint64_t i = 0; i < test_size; ++i) {
        for (uint64_t j = 0; j + i < test_size; ++j) {
            run(buf + i, VAL, j);
            test_assert(region_good(buf, i, j, test_size) == 0);
            memset(buf + i, FILL, j);
        }
    }
    return 0;
}

static int
test_memset_kernel_xl(void const * test_f, uint32_t test_size) {
    func_switch_t func = { test_f };
    uint8_t *     buf  = make_buf((1UL << 32));

    for (uint64_t i = 0; i < test_size; ++i) {
        fprintf(stderr, "%lu\n", i);
        //        for (uint64_t j = 0; j + i < test_size; ++j) {
        run(buf + i, 0, 0 + (1UL << 32) - i);
        //        }
    }
    return 0;
}


int
test_memset(void const * test_f) {
    for (uint32_t i = PAGE_SIZE; i <= 1 * PAGE_SIZE; i += 4096) {
        if (i == PAGE_SIZE) {
        }
        if (test_memset_kernel(test_f, i)) {
            return 1;
        }
        if (0 && test_memset_kernel_xl(test_f, i)) {
            return 1;
        }
    }
    return 0;
}
