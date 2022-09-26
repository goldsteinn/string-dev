#define STRLEN	wcsnlen_avx2_dev
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1
#include "core/strlen-avx2-dev.S"
