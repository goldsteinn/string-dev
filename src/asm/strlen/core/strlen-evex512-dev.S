#include "../../libc-defs/libc-evex512-vecs.h"
#ifdef USE_AS_STRNLEN
# include "strnlen-evex512-dev-split.S"
	// # include "strnlen-evex-dev-base-final.S"
#else	/* !USE_AS_STRNLEN */
# include "strlen-evex-dev-base-final.S"
#endif	/* !USE_AS_STRNLEN */
