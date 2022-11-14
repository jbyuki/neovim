#ifndef NVIM_TANGLE_LINE_H
#define NVIM_TANGLE_LINE_H

#include <stdio.h>

typedef struct Line_s Line;
typedef struct Section_s Section;
typedef struct bpnode_s bpnode;

struct Line_s
{
  enum {
    REFERENCE = 0,
		TEXT,
		SECTION
  } type;

  union {
    char* str;
    char* name;
  };
  char* prefix;

  Line* pnext, *pprev;
  bpnode* parent;
  Section* parent_section;
};


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle_line.h.generated.h"
#endif
#endif

