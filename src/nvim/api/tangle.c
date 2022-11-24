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

#include "nvim/tangle.h"

#include "nvim/bitree.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/tangle.c.generated.h"
#endif

Array nvim_tangle_get_lineinfo(Buffer buffer, Integer row, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  Array rv = ARRAY_DICT_INIT;

  if (!buf) {
    return rv;
  }

	if(buf->b_p_tgl == 0) {
		return rv;
	}

	Line* line = tree_lookup(buf->tgl_tree, row);
	if(!line) {
		return rv;
	}

	ADD(rv, STRING_OBJ(ptr_to_str(line)));

	String line_type = STRING_INIT;
	switch(line->type) {
	case REFERENCE: line_type = cstr_to_string("REFERENCE"); break;
	case SECTION: line_type = cstr_to_string("SECTION"); break;
	case TEXT: line_type = cstr_to_string("TEXT"); break;
	}
	ADD(rv, STRING_OBJ(line_type));

	ADD(rv, STRING_OBJ(ptr_to_str(line->parent_section)));

	ADD(rv, STRING_OBJ(ptr_to_str(line->pnext)));

	ADD(rv, STRING_OBJ(ptr_to_str(line->pprev)));

	return rv;
}

static String ptr_to_str(void* p)
{
	static char buffer[32];
	sprintf(buffer, "%p", p);
	return cbuf_to_string(buffer, strlen(buffer));
}



