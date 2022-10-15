#define STRCMP	wcsncmp_sse42_dev
#define WCSNCMP	STRCMP
#define USE_AS_WCSCMP	1
#define USE_AS_STRNCMP	1

#define OVERFLOW_STRCMP	wcscmp_sse42_dev

#include "core/strcmp-sse42-dev.S"
