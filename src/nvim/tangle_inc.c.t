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
void update_current_tangle_line(Line* old_line, char* buf, size_t charlen)
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
	if(new_line.type == REFERENCE) {
		@insert_text_to_reference
	}
	else if(new_line.type == SECTION) {
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
@append_text_ref_new_ref

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

@append_text_ref_new_ref+=
SectionList* list = get_section_list(&curbuf->sections, name);
kv_push(list->refs, old_line->parent_section);
