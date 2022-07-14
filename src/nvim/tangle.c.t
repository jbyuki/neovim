@./tangle.h=
#ifndef NVIM_TANGLE_H
#define NVIM_TANGLE_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"

@define_struct

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.h.generated.h"
#endif
#endif

@./tangle.c=
// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"

@includes

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

@define_functions

@includes+=
#include "nvim/message.h"

@define_functions+=
void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}
