#include "arch.h"

#include <stdio.h>
#include <string.h>

char *ask(const char *prompt)
{
    fputs(prompt, stdout);
    fflush(stdout);
    char buf[1024];
    fgets(buf, sizeof(buf), stdin);
    return strdup(buf);
}
