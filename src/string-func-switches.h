#ifndef _SRC__STRING_FUNC_SWITCHES_H_
#define _SRC__STRING_FUNC_SWITCHES_H_

#include <string.h>

#include "util/macro.h"
#include "util/types.h"

#define add_func(func) FUNC_T(func) CAT(run_, func)

typedef union func_switch {
    add_func(strrchr);
    add_func(strchr);
    add_func(wcschr);
    add_func(wcsrchr);
    add_func(wcschrnul);
    add_func(strchrnul);
    add_func(memchr);
    add_func(wmemchr);
    add_func(rawmemchr);
} func_switch_t;


#endif
