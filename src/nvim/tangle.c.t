##tangle
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

@line_struct
@section_struct
@section_list_struct

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif


@global_variables
@define_functions_linked_list
@define_functions

@includes+=
#include "nvim/message.h"

@define_functions+=
void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
  @create_tangle_buffer
  @tangle_current_buffer_initial
  @set_tangle_buffer
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

@includes+=
#include "nvim/buffer.h"
#include "nvim/option.h"

@create_tangle_buffer+=
buf_T* tangle_view = buflist_new(NULL, NULL, (linenr_T)1, BLN_NEW);
ml_open(tangle_view);

@tangle_current_buffer_initial+=
tangle_parse(buf);
tangle_output(tangle_view);

@set_tangle_buffer+=
buf->tangle_view = tangle_view;
