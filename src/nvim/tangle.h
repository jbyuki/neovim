#ifndef NVIM_TANGLE_H
#define NVIM_TANGLE_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"
#include "nvim/bitree.h"

typedef struct SectionList_s SectionList;

typedef struct LineRef_s LineRef;

struct LineRef_s
{
	Section* section;
	int64_t id;
	int prefix_len;

};

struct Section_s
{
  int total;

  int n;

  Section* pnext, *pprev;

  SectionList* parent;

  // Making whole structs instead of pointer so
  // that during btree insertion, the pointers
  // are correctly adjusted.
  Line head, tail;

};

struct SectionList_s
{
  bool root;

  int total;

  int n;

  Section* phead;
  Section* ptail;

  const char* name;

  kvec_t(LineRef) refs;

};


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.h.generated.h"
#endif
#endif

