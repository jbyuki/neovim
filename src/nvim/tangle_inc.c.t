##tangle
@define_functions+=
Line* get_current_tangle_line()
{
	@get_cursor_position
	@get_line_from_btree
	return line;
}

@get_cursor_position+=
size_t col = (size_t)curwin->w_cursor.col;
linenr_T lnum = curwin->w_cursor.lnum;

@get_line_from_btree+=
Line* line = tree_lookup(curbuf->tgl_tree, lnum-1);

@define_functions+=
void update_current_tangle_line(Line* old_line)
{
	@get_cursor_position
	@get_current_line
	@reanalyze_current_line

	@if_old_line_was_text_insert
	@if_old_line_was_reference_insert
	@if_old_line_was_section_insert

	@update_line
}

@get_current_line+=
char *line = ml_get(lnum);
size_t linelen = strlen(line) + 1;  // length of old line including NUL

@reanalyze_current_line+=
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

@if_old_line_was_text_insert+=
if(old_line->type == TEXT) {
	if(new_line.type == TEXT) {
		// Nothing to do
		return;
	} else if(new_line.type == REFERENCE) {
		@insert_text_to_reference
	} else if(new_line.type == SECTION) {
		@insert_text_to_section
	}
}

@update_line+=
*old_line = new_line;

@insert_text_to_reference+=
@get_whitespace_before
@get_reference_name

new_line.name = name;
new_line.prefix = prefix;

@compute_text_ref_delta_count_and_update
@append_new_line_reference

@compute_text_ref_delta_count_and_update+=
int delta = -1 + tangle_get_count(curbuf, name);
update_count_recursively(old_line->parent_section, delta);

@define_functions+=
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

@append_new_line_reference+=
SectionList* list = get_section_list(&curbuf->sections, name);
kv_push(list->refs, new_line.parent_section);

@if_old_line_was_reference_insert+=
else if(old_line->type == REFERENCE) {
	if(new_line.type == TEXT) {
		@insert_reference_to_text
	} else if(new_line.type == REFERENCE) {
		@insert_reference_to_reference
	} else if(new_line.type == SECTION) {
		@insert_reference_to_section
	}
}

@insert_reference_to_reference+=
@get_whitespace_before
@get_reference_name

new_line.name = name;
new_line.prefix = prefix;

@compute_delta_reference_to_reference_and_update
@remove_old_line_reference
@append_new_line_reference

@compute_delta_reference_to_reference_and_update+=
int delta = -tangle_get_count(curbuf, old_line->name) + tangle_get_count(curbuf, name);
update_count_recursively(old_line->parent_section, delta);

@remove_old_line_reference+=
SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);
remove_ref(old_list, old_line->parent_section);

@define_functions+=
static void remove_ref(SectionList* list, Section* ref)
{
	int i = 0;
	for(; i<kv_size(list->refs); ++i) {
		if(kv_A(list->refs, i) == ref) {
			break;
		}
	}
	assert(i < kv_size(list->refs));

	for(int j=i; j<kv_size(list->refs)-1; ++j) {
		kv_A(list->refs, i) = kv_A(list->refs, i+1);
	}
	kv_pop(list->refs);
}

@insert_reference_to_text+=
@compute_delta_reference_to_text_and_update
@remove_old_line_reference

@compute_delta_reference_to_text_and_update+=
int delta = -tangle_get_count(curbuf, old_line->name)+1;
update_count_recursively(old_line->parent_section, delta);

@insert_text_to_section+=
buf_T* buf = curbuf;
Section* cur_section;
@parse_operator
@parse_section_name
@create_new_section
@link_to_previous_section_if_needed
@otherwise_just_save_section

new_line.name = name;
new_line.pnext = NULL;
new_line.pprev = NULL;

@update_subsequent_lines_parent_section
@compute_removed_count_section
@remove_and_add_references
@compute_text_section_delta_count_and_update
@compute_new_section_size_and_update
@fix_section_linkedlist

@update_subsequent_lines_parent_section+=
Line* next_line = old_line->pnext;
while(next_line) {
	next_line->parent_section = section;
	next_line = next_line->pnext;
}

@define_functions+=
static int get_tangle_line_size(Line* line)
{
	if(line->type == REFERENCE) {
		return tangle_get_count(curbuf, line->name);
	} else if(line->type == TEXT) {
		return 1;
	}
	return 0;
}

@compute_removed_count_section+=
next_line = old_line->pnext;

int removed = 0;
while(next_line) {
	removed += get_tangle_line_size(next_line);
	next_line = next_line->pnext;
}

@remove_and_add_references+=
next_line = old_line;

Section* old_section = old_line->parent_section;
while(next_line) {
	if(next_line->type == REFERENCE) {
		SectionList* ref_list = get_section_list(&curbuf->sections, next_line->name);
		remove_ref(ref_list, old_line->parent_section);
		if(next_line != old_line) {
			kv_push(ref_list->refs, section);
		}
	}
	next_line = next_line->pnext;
}

@compute_text_section_delta_count_and_update+=
int delta = -get_tangle_line_size(old_line) - removed;
update_count_recursively(old_line->parent_section, delta);

@compute_new_section_size_and_update+=
delta = removed;
update_count_recursively(section, delta);

@fix_section_linkedlist+=
section->head = old_line->pnext;
section->tail = old_line->parent_section->tail;
old_line->parent_section->tail = old_line->pprev;

@insert_reference_to_section+=
buf_T* buf = curbuf;
Section* cur_section;
@parse_operator
@parse_section_name
@create_new_section
@link_to_previous_section_if_needed
@otherwise_just_save_section

new_line.name = name;
new_line.pnext = NULL;
new_line.pprev = NULL;

@update_subsequent_lines_parent_section
@compute_removed_count_section
@remove_and_add_references
@compute_text_section_delta_count_and_update
@compute_new_section_size_and_update
@fix_section_linkedlist

@if_old_line_was_section_insert+=
else if(old_line->type == SECTION) {
	if(new_line.type == TEXT) {
		@insert_section_to_text
	} else if(new_line.type == REFERENCE) {
		@insert_section_to_reference
	} else if(new_line.type == SECTION) {
		@insert_section_to_section
	}
}

@insert_section_to_text+=
Line* next_l = next_line(old_line);
Line* prev_l = prev_line(old_line);

@update_subsequent_lines_parent_section_to_previous

@move_references_to_previous_section
@remove_section
@update_count_section_text_previous_section

new_line.pnext = next_l;
new_line.pprev = prev_l;

// actually pointing to new_line because 
// new_line content will be copied old_line location
if(prev_l) {
	prev_l->pnext = old_line;
}

if(next_l) {
	next_l->pprev = old_line;
}

@update_subsequent_lines_parent_section_to_previous+=
Section* prev_section = prev_l->parent_section;

new_line.parent_section = prev_section;

Line* line_iter = next_l;
while(line_iter) {
	line_iter->parent_section = prev_section;
	line_iter = line_iter->pnext;
}

@remove_section+=
Section* section = old_line->parent_section;
int delta = section->n;
update_count_recursively(section, -delta);
sectionlist_remove(section);

@update_count_section_text_previous_section+=
update_count_recursively(prev_section, delta+1);

@move_references_to_previous_section+=
line_iter = next_l;
while(line_iter) {
	if(line_iter->type == REFERENCE) {
		SectionList* ref_list = get_section_list(&curbuf->sections, line_iter->name);
		remove_ref(ref_list, old_line->parent_section);
		kv_push(ref_list->refs, prev_section);
	}
	line_iter = line_iter->pnext;
}
