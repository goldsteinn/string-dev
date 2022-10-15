#ifndef MEMCHR
# define MEMCHR	memchr_sse2_dev
#endif
#ifdef USE_AS_RAWMEMCHR
# include "core/rawmemchr-sse2-dev.S"
#else
# include "core/memchr-sse2-dev.S"
#endif
