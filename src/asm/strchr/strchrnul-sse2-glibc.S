#ifndef STRCHR
#define STRCHR	strchrnul_sse2_glibc
#endif
#define USE_AS_STRCHRNUL 1
#include "core/strchr-sse2-glibc.S"
