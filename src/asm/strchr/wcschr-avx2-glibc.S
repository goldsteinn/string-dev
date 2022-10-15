#ifndef STRCHR
#define STRCHR	wcschr_avx2_glibc
#endif
#define USE_AS_WCSCHR 1
#include "core/strchr-avx2-glibc.S"
