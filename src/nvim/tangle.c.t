##tangle
@./tangle.h=
#ifndef NVIM_TANGLE_H
#define NVIM_TANGLE_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"
#include "nvim/bitree.h"

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
  @parse_tangle_initial
	@update_loc_data_tangle
	@create_dummy_buffer_foreach_roots
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

@includes+=
#include "nvim/buffer.h"
#include "nvim/option.h"

@parse_tangle_initial+=
tangle_parse(buf);

@create_dummy_buffer_foreach_roots+=
for(int i=0; i<buf->root_names.size; ++i) {
	const char* name = buf->root_names.items[i];
	buf_T* view_buf = buflist_new(NULL, name, 1L, BLN_DUMMY);
	kv_push(buf->tgl_bufs, view_buf->handle);
	view_buf->parent_tgl = buf;
}

