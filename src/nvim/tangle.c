// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"


#include "nvim/message.h"

#include "nvim/buffer.h"
#include "nvim/option.h"

#include "nvim/vim.h"

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


static PMap(cstr_t) is_root = MAP_INIT;

static PMap(cstr_t) sections = MAP_INIT;
static kvec_t(cstr_t) section_names = KV_INITIAL_VALUE;

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

  tangle_parse(buf);
  tangle_output(tangle_view);

  buf->tangle_view = tangle_view;
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

void ins_char_bytes_tangle(char *buf, size_t charlen)
{
}
void tangle_output(buf_T *tangle_view)
{
  for(int i=0; i<kv_size(section_names); ++i) {
  	char* name = kv_A(section_names, i);
  	bool root = pmap_has(cstr_t)(&is_root, name);

  	if(root) {
  		int line_num = 0;
  		traverseNode(tangle_view, "", name, &line_num);

  	}
  }

}

static void traverseNode(buf_T* tangle_view, char* prefix, char* name, int* line_num)
{
	if(!pmap_has(cstr_t)(&sections, name)) {
	  return;
	}

	SectionList* list = pmap_get(cstr_t)(&sections, name);
	for(Section* pcopy = list->phead; pcopy; pcopy = pcopy->pnext) {
	  for(int i=0; i<kv_size(pcopy->lines); ++i) {
	    Line l = kv_A(pcopy->lines, i);
			switch(l.type) {
			case TEXT: 
			{
			  size_t len = strlen(prefix) + strlen(l.str);
			  char* line = (char*)xmalloc(len+1);
			  STRCPY(line, prefix);
			  STRCAT(line, l.str);

			  ml_append_buf(tangle_view, *line_num, line, (colnr_T)0, false);
			  line_num++;
			  break;
			}

			case REFERENCE:
			{
			  size_t len = strlen(prefix) + strlen(l.prefix);
			  char* new_prefix = (char*)xmalloc(len+1);
			  STRCPY(new_prefix, prefix);
			  STRCAT(new_prefix, l.prefix);
			  traverseNode(tangle_view, new_prefix, l.str, line_num);
			  xfree(new_prefix);
			  break;
			}
			default: break;
			}
	  }
	}

}

void tangle_parse(buf_T *buf)
{
  pmap_clear(cstr_t)(&is_root);

  pmap_clear(cstr_t)(&sections);
  kv_destroy(section_names);
  kv_init(section_names);

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

          if(op == 0) {
            pmap_put(cstr_t)(&is_root, name, NULL);
          }

          section->name = name;

          cur_section = section;

          kv_init(section->lines);

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


