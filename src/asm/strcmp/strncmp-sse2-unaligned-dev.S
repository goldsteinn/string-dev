#define STRCMP	strncmp_sse2_unaligned_dev
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#include "core/strcmp-sse2-unaligned-dev.S"
