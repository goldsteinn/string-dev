#define STRCMP	wcscmp_sse42_dev
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "core/strcmp-sse42-dev.S"
