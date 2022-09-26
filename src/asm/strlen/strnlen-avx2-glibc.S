#define STRLEN	strnlen_avx2_glibc
#define STRNLEN	STRLEN
#define USE_AS_STRNLEN	1
#include "core/strlen-avx2-glibc.S"

