@./tangle_utils.h=
#ifndef NVIM_TANGLE_UTILS_H
#define NVIM_TANGLE_UTILS_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle_utils.h.generated.h"
#endif
#endif

@./tangle_utils.c=
// tangle_utils.c: utilities for tangle.c

#include <inttypes.h>
#include <string.h>

@includes

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle_utils.c.generated.h"
#endif

@define_functions

@includes+=
#include <ctype.h>

@define_functions+=
// Find the first occurence of a non-whitespace character
char* strnwfirst(const char* src)
{
  while(*src != '\0' && isspace(*src)) {
    src++;
  }
  if(*src == '\0') {
    return NULL;
  }

  return src;
}

// Find the last occurence of a non-whitespace character
char* strnwlast(const char* src)
{
  int len = strlen(src);
  for(int i=len-1; i>=0; --i) {
    if(!isspace(src[i])) {
      return src+i;
    }
  }
  return NULL;
}
