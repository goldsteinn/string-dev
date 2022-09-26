#define STRLEN	wcslen_avx2_dev
#define WCSLEN	STRLEN
#define USE_AS_WCSLEN	1
#include "core/strlen-avx2-dev.S"
