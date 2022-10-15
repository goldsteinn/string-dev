#ifndef STRCHR
#define STRCHR	strchrnul_avx2_glibc
#endif
#define USE_AS_STRCHRNUL 1
#include "core/strchr-avx2-glibc.S"
