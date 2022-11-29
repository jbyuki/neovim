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
void update_current_tangle_line(Line* old_line, int rel, int linecol, int old, int new)
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
char *line = ml_get(lnum + rel);
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
		@changed_text_to_text
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
		LineRef line_ref = kv_A(list->refs, i);
		update_count_recursively(line_ref.section, delta);
	}
}

@append_new_line_reference+=
SectionList* list = get_section_list(&curbuf->sections, name);
LineRef line_ref;
line_ref.section = new_line.parent_section;
line_ref.id = new_line.id;
kv_push(list->refs, line_ref);

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
{
SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);
LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
remove_ref(old_list, line_ref);
}

@define_functions+=
static void remove_ref(SectionList* list, LineRef ref)
{
	int i = 0;
	for(; i<kv_size(list->refs); ++i) {
		LineRef cur_ref = kv_A(list->refs, i);
		if(cur_ref.section == ref.section && cur_ref.id == ref.id) {
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

Line* next_l = old_line->pnext;
@update_subsequent_lines_parent_section
@compute_removed_count_section
@remove_and_add_references
@compute_text_section_delta_count_and_update
@compute_new_section_size_and_update
@fix_section_linkedlist

@update_subsequent_lines_parent_section+=
Line* next_line = next_l;
while(next_line && next_line->pnext) {
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
next_line = next_l;

int removed = 0;
while(next_line && next_line->pnext) {
	removed += get_tangle_line_size(next_line);
	next_line = next_line->pnext;
}

@remove_and_add_references+=
next_line = next_l;

Section* old_section = old_line->parent_section;
while(next_line && next_line->pnext) {
	if(next_line->type == REFERENCE) {
		SectionList* ref_list = get_section_list(&curbuf->sections, next_line->name);
		LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
		remove_ref(ref_list, old_ref);
		LineRef line_ref;
		line_ref.section = section;
		line_ref.id = next_line->id;
		kv_push(ref_list->refs, line_ref);
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
section->head.pnext = old_line->pnext;
section->tail.pprev = old_line->parent_section->tail.pprev;
old_line->parent_section->tail.pprev = old_line->pprev;

@insert_reference_to_section+=
buf_T* buf = curbuf;
Section* cur_section;
@parse_operator
@parse_section_name
@create_new_section

new_line.name = name;
new_line.pnext = NULL;
new_line.pprev = NULL;
new_line.parent_section = section;

Line* next_l = next_line(old_line);

@update_subsequent_lines_parent_section
@compute_removed_count_section
@remove_current_reference
@remove_and_add_references
@compute_text_section_delta_count_and_update
@fix_section_linkedlist

@link_to_previous_section_if_needed
@otherwise_just_save_section
@compute_new_section_size_and_update

@if_new_section_is_root_create_buf

@remove_current_reference+=
{
	SectionList* ref_list = get_section_list(&curbuf->sections, old_line->name);
	LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
	remove_ref(ref_list, line_ref);
}

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
Line* prev_l = prev_line(old_line, &curbuf->first_line);

@update_subsequent_lines_parent_section_to_previous

@move_references_to_previous_section
@remove_section
@update_count_section_text_previous_section
@append_line_to_previous_section

@append_line_to_previous_section+=
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
while(line_iter->pnext) {
	line_iter->parent_section = prev_section;
	line_iter = line_iter->pnext;
}

@remove_section+=
Section* old_s = old_line->parent_section;
int delta = old_s->n;
update_count_recursively(old_s, -delta);
sectionlist_remove(old_s);

@update_count_section_text_previous_section+=
update_count_recursively(prev_section, delta+1);

@move_references_to_previous_section+=
line_iter = next_l;
while(line_iter->pnext) {
	if(line_iter->type == REFERENCE) {
		SectionList* ref_list = get_section_list(&curbuf->sections, line_iter->name);
		LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
		remove_ref(ref_list, old_ref);
		LineRef line_ref;
		line_ref.section = prev_section;
		line_ref.id = line_iter->id;
		kv_push(ref_list->refs, line_ref);
	}
	line_iter = line_iter->pnext;
}

@insert_section_to_reference+=
@get_whitespace_before
@get_reference_name

new_line.name = name;
new_line.prefix = prefix;

Line* next_l = next_line(old_line);
Line* prev_l = prev_line(old_line, &curbuf->first_line);

@update_subsequent_lines_parent_section_to_previous

@move_references_to_previous_section
@add_current_line_reference_to_previous_section
@remove_section
@update_count_section_reference_previous_section
@append_line_to_previous_section

@add_current_line_reference_to_previous_section+=
SectionList* list = get_section_list(&curbuf->sections, name);
LineRef line_ref;
line_ref.section = prev_section;
line_ref.id = new_line.id;
kv_push(list->refs, line_ref);
if(list->n < 0) {
	list->n = 0;
}

@update_count_section_reference_previous_section+=
update_count_recursively(prev_section, delta+list->n);

@insert_section_to_section+=
buf_T* buf = curbuf;
Section* cur_section;
@parse_operator
@parse_section_name
if(strcmp(old_line->name, name) != 0) {
	@get_old_section_list

	@create_new_section
	@link_to_previous_section_if_needed
	@otherwise_just_save_section

	new_line.name = name;
	new_line.pnext = NULL;
	new_line.pprev = NULL;
	new_line.parent_section = section;

	Line* next_l = next_line(old_line);
	Line* last_l = old_line->parent_section->tail.pprev;

	@update_subsequent_lines_parent_section
	@compute_removed_count_section
	@remove_and_add_references
	@remove_section
	@update_count_section_reference_new_section
	@fix_section_linkedlist_new_section

	@if_root_section_rename
}

@update_count_section_reference_new_section+=
update_count_recursively(section, delta);

@fix_section_linkedlist_new_section+=
section->head.pnext = next_l;
section->tail.pprev = last_l;

@define_functions+=
void tangle_open_line()
{
	@get_cursor_position
	@create_empty_text_line
	buf_T* buf = curbuf;
	@assign_new_line_id
	@append_text_line_based_on_dir
	@append_text_to_current_section
	@update_count_for_current_section_append
}

@create_empty_text_line+=
Line l;
l.type = TEXT;
l.pnext = NULL;
l.pprev = NULL;

@append_text_line_based_on_dir+=
Line* pl = tree_insert(curbuf->tgl_tree, lnum-1, &l);

@define_functions+=
void insert_in_section(Section* section, Line* prev_l, Line* next_l, Line* pl)
{
	if(prev_l && prev_l->type != SECTION) {
		pl->pprev = prev_l;
		prev_l->pnext = pl;
	} else {
		section->head.pnext = pl;
		pl->pprev = &section->head;
	}

	if(next_l && next_l->type != SECTION) {
		pl->pnext = next_l;
		next_l->pprev = pl; 
	} else {
		section->tail.pprev = pl;
		pl->pnext = &section->tail;
	}

	pl->parent_section = section;
}

@append_text_to_current_section+=
Line* prev_l = prev_line(pl, &curbuf->first_line);
Line* next_l = next_line(pl);

insert_in_section(prev_l->parent_section, prev_l, next_l, pl);

@update_count_for_current_section_append+=
update_count_recursively(pl->parent_section, 1);

@define_functions+=
void tangle_delete_lines(int count)
{
	@get_cursor_position
	@get_line_from_btree
	@delete_lines_while_recording

	@update_current_section_delete
	@delete_old_sections
}

@delete_lines_while_recording+=
@deleted_lines_data

for(int j=0;j < count; ++j) {
	@if_deleted_line_is_text
	@if_deleted_line_is_reference
	@if_deleted_line_is_section

	@release_line_and_go_to_next_line
}

@deleted_lines_data+=
Line* prev_l = prev_line(line, &curbuf->first_line);
Section* prev_section = prev_l->parent_section;
Section* cur_section = prev_section;
int deleted_from_prev = 0;

@define_functions+=
void remove_line_from_section(Line* line)
{
	line->pprev->pnext = line->pnext;
	line->pnext->pprev = line->pprev;
}

@if_deleted_line_is_text+=
if(line->type == TEXT) {
	if(prev_section == cur_section) {
		deleted_from_prev++;
	}
	remove_line_from_section(line);
}

@release_line_and_go_to_next_line+=
// This could potentially be faster by avoiding
// the downward search because we already know 
// the location in the tree
line = tree_delete(curbuf->tgl_tree, lnum-1);

@if_deleted_line_is_reference+=
else if(line->type == REFERENCE) {
	if(prev_section == cur_section) {
		deleted_from_prev += tangle_get_count(curbuf, line->name);
	}

	Line* old_line = line;
	@remove_old_line_reference
	remove_line_from_section(line);
}


@update_current_section_delete+=
if(prev_section) {
	update_count_recursively(prev_section, -deleted_from_prev);
}
@update_reference_ref_deleted_section
@append_lines_other_deleted_section
@fixup_section_head_tail_pointers

@deleted_lines_data+=
kvec_t(Section*) sections_to_delete = KV_INITIAL_VALUE;

@if_deleted_line_is_section+=
else if(line->type == SECTION) {
	cur_section = line->parent_section;
	kv_push(sections_to_delete, cur_section);

	@if_deleted_section_is_root_remove_buf
}

@delete_old_sections+=
for(int i=0; i<kv_size(sections_to_delete); ++i) {
	Section* old_s = kv_A(sections_to_delete, i);


	int delta = old_s->n;
	update_count_recursively(old_s, -delta);
	sectionlist_remove(old_s);

}

@append_lines_other_deleted_section+=
if(prev_section != cur_section) {
	int added = 0;
	Line* line_n = line;
	while(line_n && line_n->pnext) {
		line_n->parent_section = prev_section;
		added += get_tangle_line_size(line_n);
		line_n = line_n->pnext;
	}

	if(prev_section) {
		update_count_recursively(prev_section, added);
	}
}

@update_reference_ref_deleted_section+=
if(prev_section != cur_section) {
	Line* line_n = line;
	while(line_n && line_n->pnext) {
		if(line_n->type == REFERENCE) {
			SectionList* ref_list = get_section_list(&curbuf->sections, line_n->name);
			LineRef old_ref = { .section = line_n->parent_section, .id = line_n->id };
			LineRef new_ref = { .section = prev_section, .id = line_n->id };
			replace_ref(ref_list, old_ref, new_ref);
		}
		line_n = line_n->pnext;
	}
}

@define_functions+=
static void replace_ref(SectionList* list, LineRef old_ref, LineRef new_ref)
{
	int i = 0;
	for(; i<kv_size(list->refs); ++i) {
		LineRef ref = kv_A(list->refs, i);
		if(ref.section == old_ref.section && ref.id == old_ref.id) {
			break;
		}
	}
	assert(i < kv_size(list->refs));
	kv_A(list->refs, i) = new_ref;
}

@fixup_section_head_tail_pointers+=
if(prev_section != cur_section) {
	@fixup_first_line_after_deleted
	@fixup_last_line_in_section
}

@fixup_first_line_after_deleted+=
Line* line_n = line;
if(line_n) {
	if(prev_l->type == SECTION) {
		line_n->pprev = &prev_section->head;
		prev_section->head.pnext = line_n;
	} else {
		line_n->pprev = prev_l;
		prev_l->pnext = line_n;
	}
}

@fixup_last_line_in_section+=
if(line_n) {
	prev_section->tail.pprev = cur_section->tail.pprev;
	cur_section->tail.pprev->pnext = &prev_section->tail;
}

@section_list_data+=
bool root;

@set_section_as_root+=
list->root = true;

@init_section_list+=
list->root = false;

@get_old_section_list+=
SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);

@if_root_section_rename+=
if(op == 0 && old_list->root) {
	@get_dummy_buffer_for_name
	@rename_buffer
}

@get_dummy_buffer_for_name+=
buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, old_line->name);
assert(dummy_buf);

@rename_buffer+=
aco_save_T aco;
aucmd_prepbuf(&aco, dummy_buf);
int ren_ret = rename_buffer(name);
aucmd_restbuf(&aco);

@if_deleted_section_is_root_remove_buf+=
SectionList* old_list = cur_section->parent;
if(old_list->root) {
	buf_T* bufdel = pmap_get(cstr_t)(&curbuf->tgl_bufs, line->str);
	assert(bufdel);

	bool force = true;
	bool unload = false;

  int result = do_buffer(DOBUF_WIPE, DOBUF_FIRST, FORWARD, bufdel->handle, force);
	pmap_del(cstr_t)(&curbuf->tgl_bufs, line->str);
}


@create_first_dummy_line+=
SectionList* top_list = get_section_list(&curbuf->sections, "__top__");
Section* top_section = (Section*)xcalloc(1, sizeof(Section));
top_section->head.pnext = &top_section->tail;
top_section->tail.pprev = &top_section->head;
sectionlist_push_back(top_list, top_section);

buf->first_line.type = SECTION;
buf->first_line.parent = NULL;
buf->first_line.parent_section = top_section;

@if_new_section_is_root_create_buf+=
if(op == 0) {
	buf_T* view_buf = buflist_new(name, NULL, 1L, BLN_DUMMY);
	pmap_put(cstr_t)(&curbuf->tgl_bufs, name, view_buf);
	view_buf->parent_tgl = curbuf;
}
