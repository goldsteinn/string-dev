#define STRCMP	wcscmp_avx2_dev
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "core/strcmp-avx2-dev.S"
