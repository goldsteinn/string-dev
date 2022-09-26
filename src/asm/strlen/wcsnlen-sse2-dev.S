#define STRLEN	wcsnlen_sse2_dev
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1

#define OVERFLOW_STRLEN	wcslen_sse2_dev

#include "core/strlen-sse2-dev.S"
