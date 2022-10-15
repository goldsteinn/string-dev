#ifndef STRCHR
#define STRCHR	wcschr_sse2_glibc
#endif
#define USE_AS_WCSCHR 1
#include "core/strchr-sse2-glibc.S"
