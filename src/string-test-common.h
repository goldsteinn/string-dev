#ifndef _SRC__STRING_TEST_COMMON_H_
#define _SRC__STRING_TEST_COMMON_H_

#include <stdint.h>

static uint32_t const alignments[] = {
    0,   1,   2,   3,   4,   7,   8,   9,   15,  16,  17,  31,  32,  33,
    63,  64,  65,  95,  96,  97,  127, 128, 129, 159, 160, 161, 191, 192,
    193, 223, 224, 225, 255, 256, 257, 287, 288, 289, 319, 320, 321,
};
static uint32_t const nalignments = sizeof(alignments) / sizeof(alignments[0]);
static uint32_t const align_max   = alignments[nalignments - 1];

static uint32_t
next_v(uint32_t cur_val, uint32_t test_size) {
    uint32_t ub        = cur_val & 4096;
    uint32_t al_bound0 = (test_size & 4096) ? 36 : 164;
    uint32_t al_bound1 = (test_size & 4096) ? 132 : align_max;
    cur_val &= 4095;
    if (cur_val <= al_bound0) {
        ++cur_val;
        goto done;
    }

    else if (cur_val < al_bound1) {
        cur_val += 15;
        goto done;
    }
    else if (cur_val >= (4096 - al_bound0)) {
        ++cur_val;
        goto done;
    }
    else if (cur_val >= (4096 - al_bound1)) {
        cur_val += 15;
        if (cur_val > (4096 - al_bound0)) {
            cur_val = 4096 - al_bound0;
        }
        goto done;
    }
    else {
        cur_val += 15;
        cur_val *= 9;
        cur_val /= 8;

        if (cur_val >= (4096 - al_bound1)) {
            cur_val = (4096 - al_bound1);
        }
        goto done;
    }

done:
    return cur_val + ub;
}


#endif
