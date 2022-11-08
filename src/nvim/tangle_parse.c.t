##tangle
@define_functions+=
void tangle_parse(buf_T *buf)
{
  @parse_variables
  for(int i=1; i<=buf->b_ml.ml_line_count; ++i) {
    char* line = ml_get(i);
    @find_first_char_non_whitespace
    @check_if_section_or_reference
    @otherwise_add_to_section
  }
}

@includes+=
#include "nvim/tangle_utils.h"

@find_first_char_non_whitespace+=
char* fp = strnwfirst(line);
if(fp == NULL) {
  continue;
}

@check_if_section_or_reference+=
if(*fp == '@') {
  if(*(fp+1) != '@') {
    @find_last_char_non_whitespace
    if(*lp == '=') {
      @parse_section
    } else {
      @parse_reference
    }
  } else {
		@create_text_line_without_at
		@add_line_to_btree
		@add_line_to_current_section
  }
}

@find_last_char_non_whitespace+=
char* lp = strnwlast(line);

@parse_section+=
@parse_operator
@parse_section_name
@create_new_section
@link_to_previous_section_if_needed
@otherwise_just_save_section

@parse_operator+=
int op;
switch(*(lp-1)) {
case '+': op = 1; break;
case '-': op = 2; break;
default: op = 0; break;
}

@includes+=
#include "nvim/vim.h"

@parse_section_name+=
size_t len = (op == 0 ? lp : lp-1) - (fp+1);
char* name = xmalloc(len + 1);
STRNCPY(name, fp+1, len);
name[len] = '\0';

@section_struct+=
typedef struct section
{
  @section_data
} Section;

@create_new_section-=
Section* section = (Section*)xmalloc(sizeof(Section));

@includes+=
#include "nvim/map.h"

@parse_variables+=
pmap_clear(cstr_t)(&buf->sections);
kv_init(buf->root_names);

@link_to_previous_section_if_needed+=
if(op == 1 || op == 2) {
  SectionList* list;
	if(!pmap_has(cstr_t)(&buf->sections, name)) {
    list = sectionlist_init();
    pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
  } else {
    list = pmap_get(cstr_t)(&buf->sections, name);
  }

  if(op == 1) {
    @add_back_to_section
  } else { /* op == 2 */
    @add_front_to_section
  }
}

@parse_variables+=
Section* cur_section = NULL;

@create_new_section+=
cur_section = section;

@add_back_to_section+=
sectionlist_push_back(list, section);

@add_front_to_section+=
sectionlist_push_front(list, section);

@otherwise_just_save_section+=
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

@parse_reference+=
@get_whitespace_before
@get_reference_name
@create_line_reference
@add_line_to_btree
@add_line_to_current_section

@get_whitespace_before+=
size_t len = fp - line;
char* prefix = xmalloc(len+1);
STRNCPY(prefix, line, len);
prefix[len] = '\0';

@get_reference_name+=
len = (lp+1)-(fp+1);
char* name = xmalloc(len+1);
STRNCPY(name, fp+1, len);
name[len] = '\0';

assert(cur_section != NULL);

@includes+=
#include <assert.h>

@create_line_reference+=
Line l;
l.type = REFERENCE;
l.name = name;
l.prefix = prefix;
l.pnext = NULL;
l.pprev = NULL;

@includes+=
#include "klib/kvec.h"

@section_data+=
Line* head, *tail;

@create_new_section+=
section->head = NULL;
section->tail = NULL;

@free_section+=
temp->head = NULL;
temp->tail = NULL;

@define_functions+=
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

@add_line_to_current_section+=
add_to_section(cur_section, pl);

@create_text_line_without_at+=
Line l;
l.type = TEXT;
l.str = xstrdup(fp+1);
l.pnext = NULL;
l.pprev = NULL;

@otherwise_add_to_section+=
else {
	@create_text_line
	@add_line_to_btree
	@add_line_to_current_section
}

@create_text_line+=
Line l;
l.type = TEXT;
l.str = xstrdup(line);
l.pnext = NULL;
l.pprev = NULL;

@includes+=
#include "nvim/bitree.h"

@parse_variables+=
buf->tgl_tree = create_tree();

@add_line_to_btree+=
Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
