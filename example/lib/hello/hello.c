#include "hello.h"

#include "arch.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *greeting(const char *name)
{
    const char *arch = get_arch();
    char buf[2048];
    snprintf(buf, sizeof(buf), "%s says: « Hello, %s! »", arch, name);
    return strdup(buf);
}
