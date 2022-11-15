// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"

#include "nvim/message.h"

#include "nvim/buffer.h"
#include "nvim/option.h"

#include "nvim/tangle_utils.h"

#include "nvim/vim.h"

#include "nvim/map.h"

#include <assert.h>

#include "klib/kvec.h"

#include "nvim/bitree.h"


typedef struct SectionList_s SectionList;

struct Section_s
{
  int n;

  Section* pnext, *pprev;

  SectionList* parent;

  Line* head, *tail;

};

struct SectionList_s
{
  int n;

  Section* phead;
  Section* ptail;

  kvec_t(Section*) refs;

};


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

static SectionList* sectionlist_init()
{
  SectionList* list = (SectionList*)xcalloc(1, sizeof(SectionList));
	list->n = -1;


  list->phead = NULL;
  list->ptail = NULL;
  return list;
}

static void sectionlist_push_back(SectionList* list, Section* section) 
{
	section->parent = list;
  if(!list->ptail) {
    list->ptail = section;
    list->phead = section;
    return;
  }

	section->pprev = list->ptail;
  list->ptail->pnext = section;
  list->ptail = section;
}

static void sectionlist_push_front(SectionList* list, Section* section) 
{
	section->parent = list;
  if(!list->phead) {
    list->phead = section;
    list->ptail = section;
    return;
  }

  section->pnext = list->phead;
	list->phead->pprev = section;
  list->phead = section;
}

static void sectionlist_clear(SectionList* list) 
{
  Section* pcopy = list->phead;
  while(pcopy) {
    Section* temp = pcopy;
    pcopy = pcopy->pnext;
    temp->head = NULL;
    temp->tail = NULL;

    xfree(temp);
  }

	kv_destroy(list->refs);
  list->phead = NULL;
  list->ptail = NULL;
}
void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
  tangle_parse(buf);

	tangle_update(buf);

	for(int i=0; i<buf->root_names.size; ++i) {
		const char* name = buf->root_names.items[i];
		buf_T* view_buf = buflist_new(name, NULL, 1L, BLN_DUMMY);
		kv_push(buf->tgl_bufs, view_buf->handle);
		view_buf->parent_tgl = buf;
	}

}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

int tangle_convert_lnum_to_untangled(buf_T* buf, const char* root, int lnum)
{
	int new_lnum;
	Line* line = get_line_at_lnum_tangled(buf, root, lnum);
	assert(line);

	new_lnum = tree_reverse_lookup(line);
	return new_lnum;
}

Line* get_line_at_lnum_tangled(buf_T* buf, const char* name, int lnum)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	while(section) {
		if(lnum < section->n) {
			Line* line = section->head;
			while(line) {
				if(line->type == TEXT) {
					if(lnum == 0) {
						return line;
					}
					lnum--;
				} else if(line->type == REFERENCE) {
					int count = tangle_get_count(buf, line->name);
					if(lnum < count) {
						return get_line_at_lnum_tangled(buf, line->name, lnum);
					}
					lnum -= count;
				}
				line = line->pnext;
			}

		}
		lnum -= section->n;
		section = section->pnext;
	}

	return NULL;
}

Line* get_current_tangle_line()
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	Line* line = tree_lookup(curbuf->tgl_tree, lnum-1);

	return line;
}

void update_current_tangle_line(Line* old_line, char* buf, size_t charlen)
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	char *line = ml_get(lnum);
	size_t linelen = strlen(line) + 1;  // length of old line including NUL

	char* fp = strnwfirst(line);
	char* lp = strnwlast(line);

	Line new_line = *old_line;
	if(fp == NULL) {
		new_line.type = TEXT;
	} else if(*fp == '@') {
	  if(*(fp+1) != '@') {
	    if(*lp == '=') {
				new_line.type = SECTION;
	    } else {
				new_line.type = REFERENCE;
	    }
	  } else {
			new_line.type = TEXT;
	  }
	} else {
		new_line.type = TEXT;
	}


	if(old_line->type == TEXT) {
		if(new_line.type == REFERENCE) {
			size_t len = fp - line;
			char* prefix = xmalloc(len+1);
			STRNCPY(prefix, line, len);
			prefix[len] = '\0';

			len = (lp+1)-(fp+1);
			char* name = xmalloc(len+1);
			STRNCPY(name, fp+1, len);
			name[len] = '\0';


			new_line.name = name;
			new_line.prefix = prefix;

			int delta = -1 + tangle_get_count(curbuf, name);
			update_count_recursively(old_line->parent_section, delta);

			SectionList* list = get_section_list(&curbuf->sections, name);
			kv_push(list->refs, old_line->parent_section);

		}
		else if(new_line.type == SECTION) {
		}
	}


	*old_line = new_line;

}

void update_count_recursively(Section* section, int delta)
{
	section->n += delta;
	SectionList* list = section->parent;
	list->n += delta;

	for (size_t i = 0; i < kv_size(list->refs); i++) {
		Section* ref = kv_A(list->refs, i);
		update_count_recursively(ref, delta);
	}
}

void tangle_update(buf_T* buf)
{
	const char* name;
	SectionList* list;
  map_foreach(&buf->sections, name, list, {
		tangle_get_count(buf, name);
  });
}

int tangle_get_count(buf_T* buf, const char* name)
{
	if(!pmap_has(cstr_t)(&buf->sections, name)) {
		return 0;
	}

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	if(list->n != -1) {
		return list->n;
	}

	list->n = 0;
	Section* section = list->phead;
	while(section) {
		section->n = 0;
		Line* line = section->head;
		while(line) {
			if(line->type == TEXT) {
				section->n++;
			} else if(line->type == REFERENCE) {
				section->n += tangle_get_count(buf, line->name);
			}
			line = line->pnext;
		}

		list->n += section->n;
		section = section->pnext;
	}

	return list->n;
}

void tangle_parse(buf_T *buf)
{
  pmap_clear(cstr_t)(&buf->sections);
  kv_init(buf->root_names);

  Section* cur_section = NULL;

  buf->tgl_tree = create_tree();

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
          section->pprev = NULL;

          cur_section = section;

          section->head = NULL;
          section->tail = NULL;

          if(op == 1 || op == 2) {
            SectionList* list = get_section_list(&buf->sections, name);

            if(op == 1) {
              sectionlist_push_back(list, section);

            } else { /* op == 2 */
              sectionlist_push_front(list, section);

            }
          }

          else {
            SectionList* list; 
            if(pmap_has(cstr_t)(&buf->sections, name)) {
              list = pmap_get(cstr_t)(&buf->sections, name);
            } else {
              list = sectionlist_init();
              pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
              kv_push(buf->root_names, name);
            }

            sectionlist_clear(list);
            sectionlist_push_back(list, section);
          }


          Line l;
          l.type = SECTION;
          l.name = name;
          l.pnext = NULL;
          l.pprev = NULL;

          Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);

        } else {
          size_t len = fp - line;
          char* prefix = xmalloc(len+1);
          STRNCPY(prefix, line, len);
          prefix[len] = '\0';

          len = (lp+1)-(fp+1);
          char* name = xmalloc(len+1);
          STRNCPY(name, fp+1, len);
          name[len] = '\0';

          Line l;
          l.type = REFERENCE;
          l.name = name;
          l.prefix = prefix;
          l.pnext = NULL;
          l.pprev = NULL;

          Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
          add_to_section(cur_section, pl);

          SectionList* list = get_section_list(&buf->sections, name);
          kv_push(list->refs, cur_section);


        }
      } else {
    		Line l;
    		l.type = TEXT;
    		l.str = xstrdup(fp+1);
    		l.pnext = NULL;
    		l.pprev = NULL;

    		Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
    		add_to_section(cur_section, pl);

      }
    }

    else {
    	Line l;
    	l.type = TEXT;
    	l.str = xstrdup(line);
    	l.pnext = NULL;
    	l.pprev = NULL;

    	Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
    	add_to_section(cur_section, pl);

    }

  }
}

static SectionList* get_section_list(PMap(cstr_t)* sections, const char* name)
{
	SectionList* list;
	if(!pmap_has(cstr_t)(sections, name)) {
    list = sectionlist_init();
    pmap_put(cstr_t)(sections, xstrdup(name), list);
  } else {
    list = pmap_get(cstr_t)(sections, name);
  }
	return list;
}

static inline void add_to_section(Section* section, Line* pl)
	FUNC_ATTR_ALWAYS_INLINE
{
	if(!section->tail) {
		section->head = pl;
		section->tail = pl;
	} else {
		section->tail->pnext = pl;
		pl->pprev = section->tail;
		section->tail = pl;
	}
	pl->parent_section = section;
}


