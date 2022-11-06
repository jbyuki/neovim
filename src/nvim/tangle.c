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
  struct section* pnext, *pprev;

  Line* head, *tail;

} Section;

typedef struct
{
  Section* phead;
  Section* ptail;

} SectionList;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

static PMap(cstr_t) sections = MAP_INIT;
static kvec_t(cstr_t) section_names = KV_INITIAL_VALUE;

static bptree* tree = NULL;

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
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

void ins_char_bytes_tangle(char *buf, size_t charlen)
{
}
void tangle_parse(buf_T *buf)
{
  pmap_clear(cstr_t)(&sections);
  kv_destroy(section_names);
  kv_init(section_names);

  Section* cur_section = NULL;

  if(tree) {
  	destroy_tree(tree);
  }
  tree = create_tree();

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
          	if(!pmap_has(cstr_t)(&sections, name)) {
              list = sectionlist_init();
              pmap_put(cstr_t)(&sections, xstrdup(name), list);
              kv_push(section_names, name);
            } else {
              list = pmap_get(cstr_t)(&sections, name);
            }

            if(op == 1) {
              sectionlist_push_back(list, section);

            } else { /* op == 2 */
              sectionlist_push_front(list, section);

            }
          }

          else {
            SectionList* list; 
            if(pmap_has(cstr_t)(&sections, name)) {
              list = pmap_get(cstr_t)(&sections, name);
            } else {
              list = sectionlist_init();
              pmap_put(cstr_t)(&sections, xstrdup(name), list);
              kv_push(section_names, name);
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

          Line* pl = tree_insert(tree, tree->total, &l);
          add_to_section(cur_section, pl);


        }
      } else {
    		Line l;
    		l.type = TEXT;
    		l.str = xstrdup(fp+1);
    		l.pnext = NULL;
    		l.pprev = NULL;

    		Line* pl = tree_insert(tree, tree->total, &l);
    		add_to_section(cur_section, pl);

      }
    }

    else {
    	Line l;
    	l.type = TEXT;
    	l.str = xstrdup(line);
    	l.pnext = NULL;
    	l.pprev = NULL;

    	Line* pl = tree_insert(tree, tree->total, &l);
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


