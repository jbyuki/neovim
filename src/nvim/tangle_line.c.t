@./tangle_line.h=
#ifndef NVIM_TANGLE_LINE_H
#define NVIM_TANGLE_LINE_H

#include <stdio.h>

@line_struct

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle_line.h.generated.h"
#endif
#endif

@./tangle_line.c=
// tangle_line.c: data structure for single line

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle_line.h"

@includes

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "tangle_line.c.generated.h"
#endif

@define

@line_struct+=
typedef struct Line_s Line;
typedef struct bpnode_s bpnode;

struct Line_s
{
  enum {
    REFERENCE = 0,
		TEXT,
  } type;

  @line_data
};

@line_data+=
union {
  char* str;
  char* name;
};
char* prefix;

Line* pnext, *pprev;
bpnode* parent;
