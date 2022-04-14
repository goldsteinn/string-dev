#include "util/arg.h"
#include "util/common.h"
#include "util/error-util.h"
#include "util/func-decl-utils.h"
#include "util/sched-util.h"
#include "util/time-util.h"
#include "util/verbosity.h"

#include "string-bench-common.h"
#include "string-func-info.h"

extern const decl_list_t string_decls;

static int32_t verbosity;

static int32_t run_all  = 0;
static int32_t do_list  = 0;
static int32_t do_test  = 0;
static int32_t do_bench = 0;

static uint32_t bench_cpu    = -1;
static uint32_t bench_v0     = 0;
static uint32_t bench_v1     = 0;
static uint32_t bench_align0 = 0;
static uint32_t bench_align1 = 0;
static uint32_t bench_sz0    = 0;
static uint32_t bench_sz1    = 0;
static uint32_t bench_trials = 10 * 1000 * 1000;

static uint32_t bench_lat  = 0;
static uint32_t bench_rand = 0;

static arg_rest_t todo = INIT_ARG_REST_T;


static ArgOption args[] = {
    /* ADD_ARG(Kind, Method, name, reqd, variable, help) */
    ADD_ARG(KindOption, Integer, ("-v"), 0, &verbosity, "Turn on verbosity"),
    ADD_ARG(KindOption,
            Integer,
            ("--bench_cpu", "--cpu", "-c"),
            0,
            &bench_cpu,
            "Bench cpu (-1 to ignore)"),
    ADD_ARG(KindOption, Set, ("--list"), 0, &do_list, "List all possibilities"),
    ADD_ARG(KindOption, Set, ("--test"), 0, &do_test, "Run tests"),
    ADD_ARG(KindOption, Set, ("--bench"), 0, &do_bench, "Run benchmarks"),
    ADD_ARG(KindOption,
            Set,
            ("--all"),
            0,
            &run_all,
            "Run all (must set tests or bench)"),
    ADD_ARG(KindOption, Set, ("--lat"), 0, &bench_lat, "Benchmark latency"),
    ADD_ARG(KindOption,
            Set,
            ("--rand"),
            0,
            &bench_rand,
            "Random benchmark (if appropriate)"),
    ADD_ARG(KindOption,
            Integer,
            ("--bench-trials", "--trials", "-t"),
            0,
            &bench_trials,
            "Number of trials to run"),
    ADD_ARG(
        KindOption,
        Integer,
        ("--align0", "--strrchr-align", "--memcpy-align0", "--memcmp-align0"),
        0,
        &bench_align0,
        "Alignment of 's'"),
    ADD_ARG(KindOption,
            Integer,
            ("--align1", "--memcpy-align1", "--memcmp-align1"),
            0,
            &bench_align1,
            "Alignment of 's'"),
    ADD_ARG(
        KindOption,
        Integer,
        ("--strrchr-len", "--memcpy-len", "--memcpy-min-len", "--memcmp-len"),
        0,
        &bench_sz0,
        "Length (of string/of copy)."),
    ADD_ARG(KindOption,
            Integer,
            ("--memcpy-max-len", "--memcmp-pos"),
            0,
            &bench_sz1,
            "Length2 (of string/of copy)."),
    ADD_ARG(KindOption, Set, ("--memcpy-dgs"), 0, &bench_v0, "dgs > src."),
    ADD_ARG(KindOption, Set, ("--memcpy-sgs"), 0, &bench_v1, "src > dst."),
    ADD_ARG(KindOption,
            Integer,
            "--strrchr-pos",
            0,
            &bench_sz1,
            "Position of search_char. -1 to fill with seach_char."),
    ADD_ARG(KindHelp, Help, ("-h", "--help"), 0, NULL, ""),
    ADD_ARG(KindRest,
            Rest,
            (""),
            0,
            &todo,
            "Impls to either test or benchmark"),
    ADD_ARG(KindEnd, EndOptions, (""), 0, NULL, "")
};


static ArgDefs argp = { args, "C / ASM Wrapper", NULL, NULL };

static bench_info_t common_binfo ALIGNED(64);

static void
set_bench_cpu(int32_t cpu) {
    if (cpu != -1) {
        setcpu_and_wait(0, cpu);
    }
}

static void
run_test(func_decl_t const * decl) {
    char const *        res   = "PASSED";
    func_info_t const * finfo = CAST(func_info_t const *, decl->data);
    printf("Testing - %-24s ...", decl->name);
    fflush(stdout);
    if (finfo->_test_func_ptr(finfo->_func_ptr)) {
        res = "FAILED";
    }
    printf("\rTesting - %-24s -> %s\n", decl->name, res);
    fflush(stdout);
}

static void
run_bench(func_decl_t const * decl) {
    func_info_t const * finfo = CAST(func_info_t const *, decl->data);
    ll_time_t           time  = 0;
    printf("Benchmarking - %-24s ...", decl->name);
    fflush(stdout);

    finfo->_bench_init_func_ptr(&common_binfo);
    time = CAST(ll_time_t, finfo->_bench_func_ptr(&common_binfo));
    printf("\rBenchmarking - %-24s -> %10.3f\n", decl->name,
           time_per_trial(time, bench_trials));
    fflush(stdout);
}


int
main(int argc, char * argv[]) {
    die_assert(!doParse(&argp, argc, argv), "Error parsing arguments\n");
    set_verbosity(verbosity);

    die_assert(do_list + do_test + do_bench == 1,
               "Must specify exactly one action\n");

    if (do_list) {
        list_decls(&string_decls);
    }
    else {
        if (do_bench) {
            set_bench_cpu(bench_cpu);
            bench_init_common(&common_binfo, bench_v0, bench_v1, bench_align0,
                              bench_align1, bench_sz0, bench_sz1, bench_trials,
                              bench_make_todo(bench_lat, bench_rand));
        }

        run_decls(&string_decls, run_all ? NULL : todo.ptrs, todo.n,
                  do_test ? &run_test : &run_bench);
    }


    return 0;
}
