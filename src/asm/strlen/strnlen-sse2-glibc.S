#define STRLEN	strnlen_sse2_glibc
#define STRNLEN	STRLEN
#define USE_AS_STRNLEN	1
#include "core/strlen-sse2-glibc.S"

