#define STRLEN	wcsnlen_evex_dev
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1
#include "core/strlen-evex-dev.S"
