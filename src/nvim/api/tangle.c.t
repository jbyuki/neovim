##tangle_api
@./tangle.h=
#ifndef NVIM_API_TANGLE_H
#define NVIM_API_TANGLE_H

#include "nvim/api/private/defs.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/map_defs.h"
#include "nvim/types.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/tangle.h.generated.h"
#endif
#endif  // NVIM_API_TANGLE_H

@./tangle.c=
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "lauxlib.h"
#include "nvim/api/tangle.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/tangle.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/pos.h"
#include "nvim/strings.h"
#include "nvim/vim.h"

@includes

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/tangle.c.generated.h"
#endif

@define_functions


@define_functions+=
Array nvim_tangle_get_lineinfo(Buffer buffer, Integer row, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  Array rv = ARRAY_DICT_INIT;

  if (!buf) {
    return rv;
  }

	@if_buffer_is_not_tangle_return
	@get_line_from_index
	@populate_tangle_line_own_pointer
	@populate_tangle_line_type
	@popualte_tangle_parent_section
	@popualte_tangle_next
	@popualte_tangle_prev
	@popualte_tangle_line_id
	@popualte_tangle_line_len

	return rv;
}

@includes+=
#include "nvim/tangle.h"

@if_buffer_is_not_tangle_return+=
if(buf->b_p_tgl == 0) {
	return rv;
}

@includes+=
#include "nvim/bitree.h"

@get_line_from_index+=
Line* line = tree_lookup(buf->tgl_tree, row);
if(!line) {
	return rv;
}

@populate_tangle_line_type+=
String line_type = STRING_INIT;
switch(line->type) {
case REFERENCE: line_type = cstr_to_string("REFERENCE"); break;
case SECTION: line_type = cstr_to_string("SECTION"); break;
case TEXT: line_type = cstr_to_string("TEXT"); break;
}
ADD(rv, STRING_OBJ(line_type));

@define_functions+=
static String ptr_to_str(void* p)
{
	static char buffer[32];
	sprintf(buffer, "%p", p);
	return cbuf_to_string(buffer, strlen(buffer));
}

@popualte_tangle_parent_section+=
ADD(rv, STRING_OBJ(ptr_to_str(line->parent_section)));

@populate_tangle_line_own_pointer+=
ADD(rv, STRING_OBJ(ptr_to_str(line)));

@popualte_tangle_next+=
ADD(rv, STRING_OBJ(ptr_to_str(line->pnext)));

@popualte_tangle_prev+=
ADD(rv, STRING_OBJ(ptr_to_str(line->pprev)));

@popualte_tangle_line_id+=
ADD(rv, INTEGER_OBJ((int)line->id));

@popualte_tangle_line_len+=
ADD(rv, INTEGER_OBJ((int)line->len));

@define_functions+=
Boolean nvim_buf_is_tangle(Buffer buffer, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
	return buf->b_p_tgl == 1;
}

@define_functions+=
ArrayOf(Integer) nvim_tangle_get_bufs(Buffer buffer, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  Array rv = ARRAY_DICT_INIT;

	if(buf->b_p_tgl == 0) {
		return rv;
	}

	const char* name;
	buf_T* pbuf;
	map_foreach(&buf->tgl_bufs, name, pbuf, {
			ADD(rv, INTEGER_OBJ(pbuf->handle));
	});
	return rv;
}
