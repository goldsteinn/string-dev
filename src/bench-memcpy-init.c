#include "bench-memcpy-init.h"

#include "util/error-util.h"
#include "util/memory-util.h"
#include "util/random.h"

memcpy_conf_t *
new_memcpy_confs(bench_todo_e todo, uint32_t min_sz, uint32_t max_sz, uint32_t dgs) {
    if(!(todo & RAND)) {
        return NULL;
    }
    die_assert(max_sz > 0 && max_sz <= (16384 - 4096));
    die_assert(min_sz < max_sz);

    uint32_t        sz_mod = max_sz - min_sz;
    memcpy_conf_t * confs =
        (memcpy_conf_t *)safe_mmap_alloc(NCONFS * sizeof(memcpy_conf_t));

    uint32_t _sz, _al_dst, _al_src, _dgs, _al0, _al1;

    for (uint32_t i = 0; i < NCONFS; ++i) {
        uint64_t rval = true_rand64();

        _dgs = (rval >> 0) & 0x1;
        if (dgs > 0 && dgs < 3) {
            _dgs = dgs >> 1;
        }
        
        _al0 = (rval >> 1) & 0xfff;
        _al1 = (rval >> 13) & 0xfff;
        _sz  = (rval >> 25) % sz_mod;

        _al_dst = _dgs ? 32768 : 0;

        _al_src = 16384 + _al0;
        _al_dst += _al1;

        confs[i].al_src = _al_src;
        confs[i].al_dst = _al_dst;
        confs[i].sz     = _sz + min_sz;
    }

    return confs;
}

void
destroy_memcpy_confs(memcpy_conf_t * confs) {
    die_assert(confs);
    safe_munmap(confs, NCONFS * sizeof(memcpy_conf_t));
}
