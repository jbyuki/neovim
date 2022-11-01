##bitree
@./bitree.h=
#ifndef NVIM_BITREE_H
#define NVIM_BITREE_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"

@define_struct

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.h.generated.h"
#endif
#endif

@./bitree.c=
// bitree.c: data structure for tangling
// 
// Based on B+ trees, this allows to do
// all operations in logarithmic time and
// with efficient cache usage.
// Bitree designates that there are two
// trees linked together where one is for
// the untangled code and the other is for
// the tangled code.

#include <inttypes.h>
#include <string.h>

#include "nvim/bitree.h"

@includes

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.c.generated.h"
#endif
