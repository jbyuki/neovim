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
@create_line_section
@add_line_to_btree

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
struct Section_s
{
  @section_data
};

@create_new_section-=
Section* section = (Section*)xcalloc(1, sizeof(Section));

@includes+=
#include "nvim/map.h"

@parse_variables+=
pmap_clear(cstr_t)(&buf->sections);
pmap_clear(cstr_t)(&buf->tgl_bufs);

@define_functions+=
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

@link_to_previous_section_if_needed+=
if(op == 1 || op == 2) {
  SectionList* list = get_section_list(&buf->sections, name);

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
    pmap_put(cstr_t)(&buf->tgl_bufs, xstrdup(name), NULL);
  }

  sectionlist_clear(list);
	@set_section_as_root
  sectionlist_push_back(list, section);
}


@create_line_section+=
Line l;
l.type = SECTION;
l.name = name;
l.pnext = NULL;
l.pprev = NULL;
l.parent_section = section;

@parse_reference+=
@get_whitespace_before
@get_reference_name
@create_line_reference
@add_line_to_btree
@add_line_to_current_section
@add_reference_to_section_list

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
// Making whole structs instead of pointer so
// that during btree insertion, the pointers
// are correctly adjusted.
Line head, tail;

@free_section+=
temp->head.pnext = NULL;
temp->tail.pprev = NULL;

@define_functions+=
static inline void add_to_section(Section* section, Line* pl)
	FUNC_ATTR_ALWAYS_INLINE
{
	if(!section->tail.pprev) {
		section->head.pnext = pl;
		section->tail.pprev = pl;
		pl->pnext = &section->tail;
		pl->pprev = &section->head;
	} else {
		section->tail.pprev->pnext = pl;
		pl->pprev = section->tail.pprev;
		pl->pnext = &section->tail;
		section->tail.pprev = pl;
	}
	pl->parent_section = section;
}

@add_line_to_current_section+=
add_to_section(cur_section, pl);

@section_list_data+=
kvec_t(Section*) refs;

@add_reference_to_section_list+=
SectionList* list = get_section_list(&buf->sections, name);
kv_push(list->refs, cur_section);

@create_text_line_without_at+=
Line l;
l.type = TEXT;
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
l.pnext = NULL;
l.pprev = NULL;

@includes+=
#include "nvim/bitree.h"

@parse_variables+=
buf->tgl_tree = create_tree();

@add_line_to_btree+=
Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);
