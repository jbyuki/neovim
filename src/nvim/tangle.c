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


typedef struct section
{
  int n;

  struct section* pnext, *pprev;

  Line* head, *tail;

} Section;

typedef struct
{
  int n;

  Section* phead;
  Section* ptail;

} SectionList;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

static SectionList* sectionlist_init()
{
  SectionList* list = (SectionList*)xmalloc(sizeof(SectionList));
	list->n = -1;


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

	section->pprev = list->ptail;
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
		buf_T* view_buf = buflist_new(NULL, name, 1L, BLN_DUMMY);
		kv_push(buf->tgl_bufs, view_buf->handle);
		view_buf->parent_tgl = buf;
	}

}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

int tangle_get_line_count(buf_T* buf, const char* root)
{
	assert(pmap_has(cstr_t)(&buf->sections, root));

	SectionList* list; 
	list = pmap_get(cstr_t)(&buf->sections, root);
	return 0;
}
void ins_char_bytes_tangle(char *buf, size_t charlen)
{
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
            SectionList* list;
          	if(!pmap_has(cstr_t)(&buf->sections, name)) {
              list = sectionlist_init();
              pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
            } else {
              list = pmap_get(cstr_t)(&buf->sections, name);
            }

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
          l.pnext = NULL;
          l.pprev = NULL;

          Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
          add_to_section(cur_section, pl);


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
}


