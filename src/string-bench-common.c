#include "util/error-util.h"
#include "util/inline-math.h"
#include "util/memory-util.h"

#include "string-bench-common.h"

static void *
check_alloc(int32_t sz) {
    if (sz > 0) {
        return safe_mmap_alloc(sz + 4096);
    }
    return NULL;
}
static void
check_free(uint8_t * p, uint32_t sz) {
    if (p && sz) {
        safe_munmap(p, sz);
    }
}

static uint32_t
get_alloc_sz(int32_t _sz0, int32_t _align0, int32_t _sz1, int32_t _align1) {
    return CMAX(_sz0 + _align0, _sz1 + _align1) * 4 + 1048576;
}

void
bench_init_common(bench_info_t * bench_info,
                  uint32_t       _v0,
                  uint32_t       _v1,
                  uint32_t       _align0,
                  uint32_t       _align1,
                  uint32_t       _sz0,
                  uint32_t       _sz1,
                  uint32_t       _trials,
                  bench_todo_e   _todo) {
    uint8_t *_s0_base, *_s1_base;
    die_assert(bench_info);

    _s0_base = check_alloc(get_alloc_sz(_sz0, _align0, _sz1, _align1));
    _s1_base = check_alloc(get_alloc_sz(_sz0, _align0, _sz1, _align1));

    bench_info->s0_base = _s0_base;
    bench_info->s1_base = _s1_base;
    bench_info->s0      = _s0_base + _align0;
    bench_info->s1      = _s1_base + _align1;
    bench_info->v0      = _v0;
    bench_info->v1      = _v1;
    bench_info->align0  = _align0;
    bench_info->align1  = _align1;
    bench_info->sz0     = _sz0;
    bench_info->sz1     = _sz1;
    bench_info->trials  = _trials;
    bench_info->todo    = _todo;
}

void
bench_free_common(bench_info_t const * bench_info) {
    die_assert(bench_info);

    check_free(bench_info->s0_base,
               get_alloc_sz(bench_info->sz0, bench_info->align0,
                            bench_info->sz1, bench_info->align1));

    check_free(bench_info->s1_base,
               get_alloc_sz(bench_info->sz0, bench_info->align0,
                            bench_info->sz1, bench_info->align1));

    check_free(bench_info->extra, bench_info->extra_sz);
}
