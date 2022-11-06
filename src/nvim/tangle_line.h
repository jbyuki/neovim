#ifndef NVIM_TANGLE_LINE_H
#define NVIM_TANGLE_LINE_H

#include <stdio.h>

typedef struct Line_s Line;

struct Line_s
{
  enum {
    REFERENCE = 0,
		TEXT,
  } type;

  union {
    char* str;
    char* name;
  };
  char* prefix;

  Line* pnext, *pprev;
};


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle_line.h.generated.h"
#endif
#endif

