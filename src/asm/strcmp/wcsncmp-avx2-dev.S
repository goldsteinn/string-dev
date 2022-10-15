#define STRCMP	wcsncmp_avx2_dev
#define WCSNCMP	STRCMP
#define USE_AS_WCSCMP	1
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP	wcscmp_avx2_dev
#include "core/strcmp-avx2-dev.S"
