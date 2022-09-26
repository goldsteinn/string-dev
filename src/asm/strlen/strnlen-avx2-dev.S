#define STRLEN	strnlen_avx2_dev
#define STRNLEN	STRLEN
#define USE_AS_STRNLEN	1
#include "core/strlen-avx2-dev.S"
