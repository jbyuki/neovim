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


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
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

}


