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
  @copy_current_buffer_to_tangle_buffer
  @set_tangle_buffer
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

@define_functions+=
void ins_char_bytes_tangle(char_u *buf, size_t charlen)
{
  @ins_char_bytes_variables
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

  @get_old_line_information
  @allocate_new_line

  @copy_old_line_before
  @copy_old_line_after
  @copy_new_character

  @replace_line_buffer

  curbuf = save_buf;
}

@includes+=
#include "nvim/state.h"
#include "nvim/ui.h"
#include "nvim/memline.h"
#include "nvim/vim.h"

@ins_char_bytes_variables+=
size_t col;
linenr_T lnum;

@get_cursor_position_insert+=
col = (size_t)curwin->w_cursor.col;
lnum = curwin->w_cursor.lnum;

@ins_char_bytes_variables+=
char_u *oldp;
size_t linelen;

@get_old_line_information+=
oldp = ml_get(lnum);
linelen = STRLEN(oldp) + 1;  // length of old line including NUL

@ins_char_bytes_variables+=
size_t oldlen;
size_t newlen;
char_u *newp;

@allocate_new_line+=
oldlen = 0;
newlen = charlen;

newp = xmalloc(linelen + newlen - oldlen);

@copy_old_line_before+=
if (col > 0) {
  memmove(newp, oldp, col);
}

@ins_char_bytes_variables+=
char_u *p;

@copy_old_line_after+=
p = newp + col;
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
#include "nvim/option.h"

@create_tangle_buffer+=
buf_T* tangle_view = buflist_new(NULL, NULL, (linenr_T)1, BLN_NEW);
ml_open(tangle_view);

@copy_current_buffer_to_tangle_buffer+=
for(int i=0; i<buf->b_ml.ml_line_count; ++i) {
  char* line = ml_get(i+1);
  if(i == 0) {
    ml_replace_buf(tangle_view, 1, line, true);
  } else {
    ml_append_buf(tangle_view, i, line, (colnr_T)STRLEN(line) + 1, false);
  }
}

@set_tangle_buffer+=
buf->tangle_view = tangle_view;

@define_functions+=
int del_bytes_tangle(colnr_T count, bool fixpos, bool use_delcombine)
{
  @del_bytes_variables

  @get_cursor_position_delete
  @get_old_line_information_delete
  @get_old_line_length_delete

  @check_if_can_delete

  @allocate_line_if_not_allocated
  @copy_line_after_delete
  @replace_line_buffer_delete

  @mark_buffer_as_deleted

  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  @get_old_line_information_delete
  @get_old_line_length_delete

  @allocate_line_if_not_allocated
  @copy_line_after_delete
  @replace_line_buffer_delete

  curbuf = save_buf;
  return OK;
}

@del_bytes_variables+=
size_t col;
linenr_T lnum;

@get_cursor_position_delete+=
col = (size_t)curwin->w_cursor.col;
lnum = curwin->w_cursor.lnum;

@del_bytes_variables+=
char_u *oldp;
size_t linelen;

@get_old_line_information_delete+=
oldp = ml_get(lnum);
linelen = STRLEN(oldp) + 1;  // length of old line including NUL

@del_bytes_variables+=
colnr_T oldlen;

@get_old_line_length_delete+=
oldlen = (colnr_T)STRLEN(oldp);

@check_if_can_delete+=
if (col >= oldlen) {
  return FAIL;
}
// If "count" is zero there is nothing to do.
if (count == 0) {
  return OK;
}

@del_bytes_variables+=
int movelen;
bool was_alloced;
char_u *newp;

@allocate_line_if_not_allocated+=
movelen = oldlen - col - count + 1;  // includes trailing NUL

was_alloced = ml_line_alloced();     // check if oldp was allocated

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

@define_functions+=
int open_line_tangle(int dir, int flags, int second_line_indent, bool *did_do_comment)
{
  @open_line_variables

  @get_cursor_position_open
  @save_cursor_delete

  @save_current_line_open
  @compute_extra_open

  @clear_some_line_states_open

  @compute_indent_open
  @append_new_line
  @truncate_current_line

  @open_line_free

  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  @save_cursor_delete

  @save_current_line_open
  @compute_extra_open

  @clear_some_line_states_open

  @compute_indent_open
  @append_new_line
  @truncate_current_line

  @open_line_free

  @move_cursor_delete

  curbuf = save_buf;
  return true;
}

@open_line_variables+=
colnr_T mincol;
linenr_T lnum;

@get_cursor_position_open+=
mincol = (size_t)curwin->w_cursor.col + 1;
lnum = curwin->w_cursor.lnum;

@open_line_variables+=
char_u *saved_line;

@includes+=
#include "nvim/cursor.h"

@save_current_line_open+=
saved_line = xstrdup(get_cursor_line_ptr());

@open_line_free+=
xfree(saved_line);

@includes+=
#include "nvim/indent.h"

@open_line_variables+=
char_u *p_extra = NULL;
bool do_si = may_do_si();
char_u *p;
int first_char = NUL;
int extra_len = 0;
char_u saved_char = NUL;

@compute_extra_open+=
if ((State & MODE_INSERT) && (State & VREPLACE_FLAG) == 0) {
  p_extra = saved_line + curwin->w_cursor.col;
  if (do_si) {  // need first char after new line break
    p = (char_u *)skipwhite((char *)p_extra);
    first_char = *p;
  }
  extra_len = (int)STRLEN(p_extra);
  saved_char = *p_extra;
  *p_extra = NUL;
}

@includes+=
#include "nvim/undo.h"

@clear_some_line_states_open+=
u_clearline();
did_si = false;
ai_col = 0;

@open_line_variables+=
colnr_T less_cols = 0;

@compute_indent_open+=
less_cols = (int)(p_extra - saved_line);
end_comment_pending = NUL;

if (p_extra == NULL) {
  p_extra = (char_u *)"";                 // append empty line
}

@open_line_variables+=
pos_T old_cursor;
bool did_append;

@save_cursor_delete+=
old_cursor = curwin->w_cursor;

@append_new_line+=
curbuf_splice_pending++;

if ((State & VREPLACE_FLAG) == 0 || old_cursor.lnum >= orig_line_count) {
  ml_append(curwin->w_cursor.lnum, (char *)p_extra, (colnr_T)0, false);
  did_append = true;
}

@includes+=
#include <nvim/extmark.h>

@open_line_variables+=
bool trunc_line = false;
colnr_T newcol = 0;
bcount_t extra;

@truncate_current_line+=
if (dir == FORWARD) {
  if (trunc_line || (State & MODE_INSERT)) {
    // truncate current line at cursor
    if (did_append) {
      changed_lines(curwin->w_cursor.lnum, curwin->w_cursor.col,
                    curwin->w_cursor.lnum + 1, 1L, true);
      did_append = false;
    } else {
      changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);
    }
  }

  old_cursor.lnum += 1;
}

if (did_append) {
  changed_lines(old_cursor.lnum, 0, old_cursor.lnum, 1L, true);
  // bail out and just get the final length of the line we just manipulated
  extra = (bcount_t)STRLEN(ml_get(old_cursor.lnum));
  extmark_splice(curbuf, (int)old_cursor.lnum - 1, 0,
                 0, 0, 0, 1, 0, 1 + extra, kExtmarkUndo);
}

curbuf_splice_pending--;

@move_cursor_delete+=
curwin->w_cursor.lnum = old_cursor.lnum;

curwin->w_cursor.col = newcol;
curwin->w_cursor.coladd = 0;

@define_functions+=
void del_lines_tangle(long nlines, bool undo)
{
  @del_lines_variables

  @get_first_line_to_delete
  @save_lines_for_undo_del_line
  @del_lines
  @changed_lines_del_line

  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  @save_lines_for_undo_del_line
  @del_lines
  @changed_lines_del_line

  curbuf = save_buf;

  @adjust_cursor_del_line
}

@del_lines_variables+=
long n;
linenr_T first;

@get_first_line_to_delete+=
first = curwin->w_cursor.lnum;

@save_lines_for_undo_del_line+=
if (undo && u_savedel(first, nlines) == FAIL) {
  return;
}

@del_lines+=
for (n = 0; n < nlines;) {
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {  // nothing to delete
    break;
  }

  ml_delete(first, true);
  n++;

  // If we delete the last line in the file, stop
  if (first > curbuf->b_ml.ml_line_count) {
    break;
  }
}

@adjust_cursor_del_line+=
curwin->w_cursor.col = 0;
check_cursor_lnum();

@changed_lines_del_line+=
deleted_lines_mark(first, n);
