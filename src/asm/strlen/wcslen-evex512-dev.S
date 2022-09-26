#define STRLEN	wcslen_evex512_dev
#define WCSLEN	STRLEN
#define REG_WIDTH	32
#define USE_AS_WCSLEN	1
#include "core/strlen-evex512-dev.S"
