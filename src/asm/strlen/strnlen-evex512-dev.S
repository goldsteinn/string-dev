#define STRLEN				strnlen_evex512_dev

#define VEC_SIZE			64
#define USE_AS_STRNLEN			1
#include "core/strlen-evex-dev.S"
