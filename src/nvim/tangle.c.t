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
  @create_tangle_buffer
  @set_tangle_buffer
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

  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  @get_old_line_information_tangle
  @allocate_new_line_tangle

  @copy_old_line_before_tangle
  @copy_old_line_after_tangle
  @copy_new_character_tangle

  @replace_line_buffer_tangle

  curbuf = save_buf;
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

@includes+=
#include "nvim/buffer.h"

@create_tangle_buffer+=
buf_T* tangle_view = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY | BLN_LISTED);

@set_tangle_buffer+=
buf->tangle_view = tangle_view;

@get_old_line_information_tangle+=
oldp = ml_get_buf(curbuf, lnum, false);
linelen = STRLEN(oldp) + 1;  // length of old line including NUL

@allocate_new_line_tangle+=
oldlen = 0;
newlen = charlen;

newp = xmalloc(linelen + newlen - oldlen);

@copy_old_line_before_tangle+=
if (col > 0) {
  memmove(newp, oldp, col);
}

@copy_old_line_after_tangle+=
p = newp + col;
if (linelen > col + oldlen) {
  memmove(p + newlen, oldp + col + oldlen,
          (size_t)(linelen - col - oldlen));
}

@copy_new_character_tangle+=
memmove(p, buf, charlen);
for (size_t i = charlen; i < newlen; i++) {
  p[i] = ' ';
}

@replace_line_buffer_tangle+=
ml_replace(lnum, (char *)newp, false);

@define_functions+=
int del_bytes_tangle(colnr_T count, bool fixpos, bool use_delcombine)
{
  @get_cursor_position_insert
  @get_old_line_information
  @get_old_line_length

  @check_if_can_delete

  @allocate_line_if_not_allocated
  @copy_line_after_delete
  @replace_line_buffer_delete

  @mark_buffer_as_deleted


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  @get_old_line_information_tangle
  @get_old_line_length_tangle

  @allocate_line_if_not_allocated_tangle
  @copy_line_after_delete
  @replace_line_buffer_delete

  curbuf = save_buf;
  return OK;
}

@get_old_line_length+=
colnr_T oldlen = (colnr_T)STRLEN(oldp);

@check_if_can_delete+=
if (col >= oldlen) {
  return FAIL;
}
// If "count" is zero there is nothing to do.
if (count == 0) {
  return OK;
}

@allocate_line_if_not_allocated+=
int movelen = oldlen - col - count + 1;  // includes trailing NUL

bool was_alloced = ml_line_alloced();     // check if oldp was allocated

char_u *newp;
if (was_alloced) {
  ml_add_deleted_len(curbuf->b_ml.ml_line_ptr, oldlen);
  newp = oldp;                            // use same allocated memory
} else {                                  // need to allocate a new line
  newp = xmalloc((size_t)(oldlen + 1 - count));
  memmove(newp, oldp, (size_t)col);
}

@copy_line_after_delete+=
memmove(newp + col, oldp + col + count, (size_t)movelen);

@replace_line_buffer_delete+=
if (!was_alloced) {
  ml_replace(lnum, (char *)newp, false);
}

@mark_buffer_as_deleted+=
inserted_bytes(lnum, col, count, 0);

@get_old_line_length_tangle+=
oldlen = (colnr_T)STRLEN(oldp);

@allocate_line_if_not_allocated_tangle+=
movelen = oldlen - col - count + 1;  // includes trailing NUL

was_alloced = ml_line_alloced();     // check if oldp was allocated

if (was_alloced) {
  ml_add_deleted_len(curbuf->b_ml.ml_line_ptr, oldlen);
  newp = oldp;                            // use same allocated memory
} else {                                  // need to allocate a new line
  newp = xmalloc((size_t)(oldlen + 1 - count));
  memmove(newp, oldp, (size_t)col);
}
