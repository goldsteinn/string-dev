#define STRRCHR	wcsrchr_evex512_glibc
#define VEC_SIZE	64
#define USE_AS_WCSRCHR	1
#include "core/strrchr-evex512-glibc.S"
