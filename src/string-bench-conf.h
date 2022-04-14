#ifndef _SRC__STRING_BENCH_CONF_H_
#define _SRC__STRING_BENCH_CONF_H_

#define bench_tput(to_run) compiler_do_not_optimize_out(to_run)
#define bench_lat(to_run)                                                      \
    compiler_do_not_optimize_out(to_run);                                      \
    serialize_ooe();
#define bench_name(func) CAT(bench_, func)

typedef enum bench_todo { TPUT = 1, LAT = 2, RAND = 4 } bench_todo_e;
enum { NCONFS = 8192 };

#endif
