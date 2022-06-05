#define STRLEN				wcsnlen_evex512_dev
#define USE_AS_WCSLEN			1
#define USE_AS_STRNLEN			1
#define VEC_SIZE			64
#include "core/strlen-evex-dev.S"
