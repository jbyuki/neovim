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

@define_functions+=
void ins_char_bytes_tangle(char_u *buf, size_t charlen)
{
  @get_cursor_position_insert
  @get_old_line_information
  @allocate_new_line

  @copy_old_line_before
  @copy_old_line_after
  @copy_new_character

  @replace_line_buffer
  @mark_buffer_as_changed
  @move_cursor_in_insert
}

@includes+=
#include "nvim/state.h"
#include "nvim/ui.h"
#include "nvim/memline.h"
#include "nvim/vim.h"

@get_cursor_position_insert+=
size_t col = (size_t)curwin->w_cursor.col;
linenr_T lnum = curwin->w_cursor.lnum;

@get_old_line_information+=
char_u *oldp = ml_get(lnum);
size_t linelen = STRLEN(oldp) + 1;  // length of old line including NUL

@allocate_new_line+=
size_t oldlen = 0;
size_t newlen = charlen;

char_u *newp = xmalloc(linelen + newlen - oldlen);

@copy_old_line_before+=
if (col > 0) {
  memmove(newp, oldp, col);
}

@copy_old_line_after+=
char_u *p = newp + col;
if (linelen > col + oldlen) {
  memmove(p + newlen, oldp + col + oldlen,
          (size_t)(linelen - col - oldlen));
}

@copy_new_character+=
memmove(p, buf, charlen);
for (size_t i = charlen; i < newlen; i++) {
  p[i] = ' ';
}

@replace_line_buffer+=
ml_replace(lnum, (char *)newp, false);

@includes+=
#include "change.h"

@mark_buffer_as_changed+=
inserted_bytes(lnum, (colnr_T)col, (int)oldlen, (int)newlen);

@move_cursor_in_insert+=
if (!p_ri || (State & REPLACE_FLAG)) {
  // Normal insert: move cursor right
  curwin->w_cursor.col += (int)charlen;
}

