// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"

#include "nvim/message.h"

#include "nvim/state.h"
#include "nvim/ui.h"
#include "nvim/memline.h"
#include "nvim/vim.h"

#include "change.h"

#include "nvim/buffer.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
  buf_T* tangle_view = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY | BLN_LISTED);

  buf->tangle_view = tangle_view;

}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

void ins_char_bytes_tangle(char_u *buf, size_t charlen)
{
  size_t col = (size_t)curwin->w_cursor.col;
  linenr_T lnum = curwin->w_cursor.lnum;

  char_u *oldp = ml_get(lnum);
  size_t linelen = STRLEN(oldp) + 1;  // length of old line including NUL

  size_t oldlen = 0;
  size_t newlen = charlen;

  char_u *newp = xmalloc(linelen + newlen - oldlen);


  if (col > 0) {
    memmove(newp, oldp, col);
  }

  char_u *p = newp + col;
  if (linelen > col + oldlen) {
    memmove(p + newlen, oldp + col + oldlen,
            (size_t)(linelen - col - oldlen));
  }

  memmove(p, buf, charlen);
  for (size_t i = charlen; i < newlen; i++) {
    p[i] = ' ';
  }


  ml_replace(lnum, (char *)newp, false);


  inserted_bytes(lnum, (colnr_T)col, (int)oldlen, (int)newlen);

  if (!p_ri || (State & REPLACE_FLAG)) {
    // Normal insert: move cursor right
    curwin->w_cursor.col += (int)charlen;
  }


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  oldp = ml_get_buf(curbuf, lnum, false);
  linelen = STRLEN(oldp) + 1;  // length of old line including NUL

  oldlen = 0;
  newlen = charlen;

  newp = xmalloc(linelen + newlen - oldlen);


  if (col > 0) {
    memmove(newp, oldp, col);
  }

  p = newp + col;
  if (linelen > col + oldlen) {
    memmove(p + newlen, oldp + col + oldlen,
            (size_t)(linelen - col - oldlen));
  }

  memmove(p, buf, charlen);
  for (size_t i = charlen; i < newlen; i++) {
    p[i] = ' ';
  }


  ml_replace(lnum, (char *)newp, false);


  curbuf = save_buf;
}

int del_bytes_tangle(colnr_T count, bool fixpos, bool use_delcombine)
{
  size_t col = (size_t)curwin->w_cursor.col;
  linenr_T lnum = curwin->w_cursor.lnum;

  char_u *oldp = ml_get(lnum);
  size_t linelen = STRLEN(oldp) + 1;  // length of old line including NUL

  colnr_T oldlen = (colnr_T)STRLEN(oldp);


  if (col >= oldlen) {
    return FAIL;
  }
  // If "count" is zero there is nothing to do.
  if (count == 0) {
    return OK;
  }


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

  memmove(newp + col, oldp + col + count, (size_t)movelen);

  if (!was_alloced) {
    ml_replace(lnum, (char *)newp, false);
  }


  inserted_bytes(lnum, col, count, 0);



  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  oldp = ml_get_buf(curbuf, lnum, false);
  linelen = STRLEN(oldp) + 1;  // length of old line including NUL

  oldlen = (colnr_T)STRLEN(oldp);


  movelen = oldlen - col - count + 1;  // includes trailing NUL

  was_alloced = ml_line_alloced();     // check if oldp was allocated

  if (was_alloced) {
    ml_add_deleted_len(curbuf->b_ml.ml_line_ptr, oldlen);
    newp = oldp;                            // use same allocated memory
  } else {                                  // need to allocate a new line
    newp = xmalloc((size_t)(oldlen + 1 - count));
    memmove(newp, oldp, (size_t)col);
  }
  memmove(newp + col, oldp + col + count, (size_t)movelen);

  if (!was_alloced) {
    ml_replace(lnum, (char *)newp, false);
  }


  curbuf = save_buf;
  return OK;
}


