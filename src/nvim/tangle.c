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
#include "nvim/option.h"

#include "nvim/cursor.h"

#include "nvim/indent.h"

#include "nvim/undo.h"

#include <nvim/extmark.h>

#include "nvim/tangle_utils.h"

#include "nvim/map.h"

#include <assert.h>

#include "klib/kvec.h"


typedef struct
{
  enum {
    REFERENCE = 0,
    TEXT,

  } type;

  union {
    char* str;
    char* name;
  };
  char* prefix;

} Line;

typedef struct section
{
  struct section* pnext;

  char* name;

  kvec_t(Line) lines;

} Section;

typedef struct
{
  Section* phead;
  Section* ptail;

} SectionList;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif


static SectionList* sectionlist_init()
{
  SectionList* list = (SectionList*)xmalloc(sizeof(SectionList));

  list->phead = NULL;
  list->ptail = NULL;
  return list;
}

static void sectionlist_push_back(SectionList* list, Section* section) 
{
  if(!list->ptail) {
    list->ptail = section;
    list->phead = section;
    return;
  }

  list->ptail->pnext = section;
  list->ptail = section;
}

static void sectionlist_push_front(SectionList* list, Section* section) 
{
  if(!list->phead) {
    list->phead = section;
    list->ptail = section;
    return;
  }

  section->pnext = list->phead;
  list->phead = section;
}

static void sectionlist_clear(SectionList* list) 
{
  Section* pcopy = list->phead;
  while(pcopy) {
    Section* temp = pcopy;
    pcopy = pcopy->pnext;
    kv_destroy(temp->lines);

    xfree(temp->name);
    xfree(temp);
  }

  list->phead = NULL;
  list->ptail = NULL;
}
void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
  buf_T* tangle_view = buflist_new(NULL, NULL, (linenr_T)1, BLN_NEW);
  ml_open(tangle_view);

  tangle_parse(buf, tangle_view);
  // @copy_current_buffer_to_tangle_buffer
  buf->tangle_view = tangle_view;

}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

void ins_char_bytes_tangle(char_u *buf, size_t charlen)
{
  size_t col;
  linenr_T lnum;

  char_u *oldp;
  size_t linelen;

  size_t oldlen;
  size_t newlen;
  char_u *newp;

  char_u *p;

  col = (size_t)curwin->w_cursor.col;
  lnum = curwin->w_cursor.lnum;

  oldp = ml_get(lnum);
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


  inserted_bytes(lnum, (colnr_T)col, (int)oldlen, (int)newlen);

  if (!p_ri || (State & REPLACE_FLAG)) {
    // Normal insert: move cursor right
    curwin->w_cursor.col += (int)charlen;
  }


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  oldp = ml_get(lnum);
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
  size_t col;
  linenr_T lnum;

  char_u *oldp;
  size_t linelen;

  colnr_T oldlen;

  int movelen;
  bool was_alloced;
  char_u *newp;


  col = (size_t)curwin->w_cursor.col;
  lnum = curwin->w_cursor.lnum;

  oldp = ml_get(lnum);
  linelen = STRLEN(oldp) + 1;  // length of old line including NUL

  oldlen = (colnr_T)STRLEN(oldp);


  if (col >= oldlen) {
    return FAIL;
  }
  // If "count" is zero there is nothing to do.
  if (count == 0) {
    return OK;
  }


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


  inserted_bytes(lnum, col, count, 0);


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  oldp = ml_get(lnum);
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

int open_line_tangle(int dir, int flags, int second_line_indent, bool *did_do_comment)
{
  colnr_T mincol;
  linenr_T lnum;

  char_u *saved_line;

  char_u *p_extra = NULL;
  bool do_si = may_do_si();
  char_u *p;
  int first_char = NUL;
  int extra_len = 0;
  char_u saved_char = NUL;

  colnr_T less_cols = 0;

  pos_T old_cursor;
  bool did_append;

  bool trunc_line = false;
  colnr_T newcol = 0;
  bcount_t extra;


  mincol = (size_t)curwin->w_cursor.col + 1;
  lnum = curwin->w_cursor.lnum;

  old_cursor = curwin->w_cursor;


  saved_line = xstrdup(get_cursor_line_ptr());

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


  u_clearline();
  did_si = false;
  ai_col = 0;


  less_cols = (int)(p_extra - saved_line);
  end_comment_pending = NUL;

  if (p_extra == NULL) {
    p_extra = (char_u *)"";                 // append empty line
  }

  curbuf_splice_pending++;

  if ((State & VREPLACE_FLAG) == 0 || old_cursor.lnum >= orig_line_count) {
    ml_append(curwin->w_cursor.lnum, (char *)p_extra, (colnr_T)0, false);
    did_append = true;
  }

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


  xfree(saved_line);


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  old_cursor = curwin->w_cursor;


  saved_line = xstrdup(get_cursor_line_ptr());

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


  u_clearline();
  did_si = false;
  ai_col = 0;


  less_cols = (int)(p_extra - saved_line);
  end_comment_pending = NUL;

  if (p_extra == NULL) {
    p_extra = (char_u *)"";                 // append empty line
  }

  curbuf_splice_pending++;

  if ((State & VREPLACE_FLAG) == 0 || old_cursor.lnum >= orig_line_count) {
    ml_append(curwin->w_cursor.lnum, (char *)p_extra, (colnr_T)0, false);
    did_append = true;
  }

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


  xfree(saved_line);


  curwin->w_cursor.lnum = old_cursor.lnum;

  curwin->w_cursor.col = newcol;
  curwin->w_cursor.coladd = 0;


  curbuf = save_buf;
  return true;
}

void del_lines_tangle(long nlines, bool undo)
{
  long n;
  linenr_T first;


  first = curwin->w_cursor.lnum;

  if (undo && u_savedel(first, nlines) == FAIL) {
    return;
  }

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

  deleted_lines_mark(first, n);


  buf_T* save_buf = curbuf;
  curbuf = curbuf->tangle_view;

  if (undo && u_savedel(first, nlines) == FAIL) {
    return;
  }

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

  deleted_lines_mark(first, n);


  curbuf = save_buf;

  curwin->w_cursor.col = 0;
  check_cursor_lnum();

}

void tangle_parse(buf_T *buf, buf_T *tangle_view)
{
  PMap(cstr_t) sections = MAP_INIT;

  Section* cur_section = NULL;

  for(int i=1; i<=buf->b_ml.ml_line_count; ++i) {
    char* line = ml_get(i);
    char* fp = strnwfirst(line);
    if(fp == NULL) {
      continue;
    }

    if(*fp == '@') {
      if(*(fp+1) != '@') {
        char* lp = strnwlast(line);

        if(*lp == '=') {
          int op;
          switch(*(lp-1)) {
          case '+': op = 1; break;
          case '-': op = 2; break;
          default: op = 0; break;
          }

          size_t len = (op == 0 ? lp : lp-1) - (fp+1);
          char* name = xmalloc(len + 1);
          STRNCPY(name, fp+1, len);
          name[len] = '\0';

          Section* section = (Section*)xmalloc(sizeof(Section));

          section->pnext = NULL;

          section->name = name;

          kv_init(section->lines);

          if(op == 1 || op == 2) {
            SectionList* list;
          	if(!pmap_has(cstr_t)(&sections, name)) {
              list = sectionlist_init();
              pmap_put(cstr_t)(&sections, xstrdup(name), list);
            } else {
              list = pmap_get(cstr_t)(&sections, name);
            }

            if(op == 1) {
              sectionlist_push_back(list, section);
              cur_section = section;

            } else { /* op == 2 */
              sectionlist_push_front(list, section);
              cur_section = section;

            }
          }

          else {
            SectionList* list; 
            if(pmap_has(cstr_t)(&sections, name)) {
              list = pmap_get(cstr_t)(&sections, name);
            } else {
              list = sectionlist_init();
              pmap_put(cstr_t)(&sections, xstrdup(name), list);
            }

            sectionlist_clear(list);
            sectionlist_push_back(list, section);
          }


        } else {
          size_t len = fp - line;
          char* prefix = xmalloc(len+1);
          STRNCPY(prefix, line, len);
          prefix[len] = '\0';

          len = (lp+1)-(fp+1);
          char* name = xmalloc(len+1);
          STRNCPY(name, fp+1, len);
          name[len] = '\0';

          assert(cur_section != NULL);

          Line l;
          l.type = REFERENCE;
          l.name = name;
          l.prefix = prefix;

          kv_push(cur_section->lines, l);


        }
      } else {
    		Line l;
    		l.type = TEXT;
    		l.str = xstrdup(fp+1);

    		kv_push(cur_section->lines, l);

      }
    }

    else {
    	Line l;
    	l.type = TEXT;
    	l.str = xstrdup(line);
    	kv_push(cur_section->lines, l);

    }

  }
}


