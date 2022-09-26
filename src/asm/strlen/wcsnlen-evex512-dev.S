#define STRLEN	wcsnlen_evex512_dev
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1
#include "core/strlen-evex512-dev.S"
