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

@declare_struct
@line_ref_struct
@section_struct
@section_list_struct

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

@define_functions_linked_list
@define_functions

@includes+=
#include "nvim/message.h"

@define_functions+=
void attach_tangle(buf_T *buf) 
{
  // semsg(_("Tangle activated!"));
  @parse_tangle_initial
	@update_loc_data_tangle
	@create_dummy_buffer_foreach_roots
}

void deattach_tangle(buf_T *buf) 
{
  // semsg(_("Tangle deactivated!"));
}

@includes+=
#include "nvim/buffer.h"
#include "nvim/option.h"

@parse_tangle_initial+=
tangle_parse(buf);

@create_dummy_buffer_foreach_roots+=
kvec_t(cstr_t) root_names = KV_INITIAL_VALUE;
const char* name;
buf_T* pbuf;
map_foreach(&buf->tgl_bufs, name, pbuf, {
	kv_push(root_names, name);
});

for(int i=0; i<kv_size(root_names); ++i) {
	const char* root_name = kv_A(root_names, i);

	buf_T* view_buf = buflist_new(root_name, NULL, 1L, BLN_DUMMY);
	pmap_put(cstr_t)(&buf->tgl_bufs, name, view_buf);
	view_buf->parent_tgl = buf;
}
