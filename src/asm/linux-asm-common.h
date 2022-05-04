#ifndef _SRC__ASM__LINUX_ASM_COMMON_H_
#define _SRC__ASM__LINUX_ASM_COMMON_H_

#define SYM_FUNC_START ENTRY
#define SYM_FUNC_END   END
#define SYM_FUNC_START_LOCAL ENTRY
#define RET ret
#define FRAME_END
#define FRAME_BEGIN
#include "asm-common.h"
#endif
