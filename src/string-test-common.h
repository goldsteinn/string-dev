#ifndef _SRC__STRING_TEST_COMMON_H_
#define _SRC__STRING_TEST_COMMON_H_

#include <stdint.h>

static uint32_t const alignments[] = {
    0,   1,   2,   3,   4,   7,   8,   9,   15,  16,  17,  31,  32,
    33,  63,  64,  65,  95,  96,  97,  127, 128, 129, 159, 160, 161,
    191, 192, 193, 223, 224, 225, 255, 256, 257, 287, 288, 289, 319,
    320, 321, 383, 384, 385, 443, 444, 445, 511, 512, 513
};
static uint32_t const nalignments = sizeof(alignments) / sizeof(alignments[0]);
static uint32_t const align_max   = alignments[nalignments - 1];

static uint32_t
next_v(uint32_t cur_val, uint32_t test_size) {
    uint32_t ub        = cur_val & 4096;
    uint32_t al_bound0 = 164;
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


#define NPAIRS    15
#define S1_IDX(x) ((x) << 1)
#define S2_IDX(x) (((x) << 1) + 1)

static void
make_alignment_pairs(uint64_t * pairs, uint32_t alignment) {
    pairs[S1_IDX(0)] = 0;
    pairs[S2_IDX(0)] = alignment;

    pairs[S1_IDX(1)] = alignment;
    pairs[S2_IDX(1)] = 0;

    pairs[S1_IDX(2)] = alignment;
    pairs[S2_IDX(2)] = alignment;

    pairs[S1_IDX(3)] = !!alignment;
    pairs[S2_IDX(3)] = alignment;

    pairs[S1_IDX(4)] = alignment;
    pairs[S2_IDX(4)] = !!alignment;

    pairs[S1_IDX(5)] = (alignment * 3) / 5;
    pairs[S2_IDX(5)] = alignment / 3;

    pairs[S1_IDX(6)] = alignment / 3;
    pairs[S2_IDX(6)] = (alignment * 3) / 5;

    pairs[S1_IDX(7)] = alignment - (!!alignment);
    pairs[S2_IDX(7)] = alignment;

    pairs[S1_IDX(8)] = alignment;
    pairs[S2_IDX(8)] = alignment - (!!alignment);

    pairs[S1_IDX(9)] = alignment - (alignment >= 2 ? 2 : 0);
    pairs[S2_IDX(9)] = alignment;

    pairs[S1_IDX(10)] = alignment - (alignment >= 3 ? 3 : 0);
    pairs[S2_IDX(10)] = alignment;

    pairs[S1_IDX(11)] = alignment - (alignment >= 5 ? 5 : 0);
    pairs[S2_IDX(11)] = alignment;

    pairs[S1_IDX(12)] = alignment - (alignment >= 9 ? 9 : 0);
    pairs[S2_IDX(12)] = alignment;

    pairs[S1_IDX(13)] = alignment - (alignment >= 17 ? 17 : 0);
    pairs[S2_IDX(13)] = alignment;

    pairs[S1_IDX(14)] = alignment - (alignment >= 33 ? 33 : 0);
    pairs[S2_IDX(14)] = alignment;

    pairs[S1_IDX(9)] = alignment;
    pairs[S2_IDX(9)] = alignment - (alignment >= 2 ? 2 : 0);

    pairs[S1_IDX(10)] = alignment;
    pairs[S2_IDX(10)] = alignment - (alignment >= 3 ? 3 : 0);

    pairs[S1_IDX(11)] = alignment;
    pairs[S2_IDX(11)] = alignment - (alignment >= 5 ? 5 : 0);

    pairs[S1_IDX(12)] = alignment;
    pairs[S2_IDX(12)] = alignment - (alignment >= 9 ? 9 : 0);

    pairs[S1_IDX(13)] = alignment;
    pairs[S2_IDX(13)] = alignment - (alignment >= 17 ? 17 : 0);

    pairs[S1_IDX(14)] = alignment;
    pairs[S2_IDX(14)] = alignment - (alignment >= 33 ? 33 : 0);
}

#endif
