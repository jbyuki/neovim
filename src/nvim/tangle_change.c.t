##tangle
@define_functions+=
// Buffers should be first changed THEN the callbacks should be notified.
void tangle_inserted_bytes(int offset, colnr_T col, int old, int new, Section* section)
{
	@get_offset_to_parent_list
	@if_root_send_inserted_changes
	@otherwise_recurse_on_references_for_inserted_changes
}

@define_functions+=
int relative_offset_section(Line* line)
{
	int offset = 0;
	Line* line_iter = line->pprev;
	while(line_iter->pprev) {
		int n, bytes;
		get_tangle_line_size(line_iter, &n, &bytes);
		offset += n;
		line_iter = line_iter->pprev;
	}
	return offset;
}

@get_offset_to_parent_list+=
Section* section_iter = section->pprev;
while(section_iter) {
	offset += section_iter->n;
	section_iter = section_iter->pprev;
}

@if_root_send_inserted_changes+=
SectionList* list = section->parent;
if(list->root) {
	buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, list->name);

	aco_save_T aco;
	aucmd_prepbuf(&aco, dummy_buf);
	inserted_bytes(offset+1, col, old, new);
	aucmd_restbuf(&aco);
}

@define_functions+=
int get_line_from_ref(LineRef line_ref, Line** line)
{
	Section* section = line_ref.section;
	int offset = 0;
	Line* line_iter = section->head.pnext;
	while(line_iter->pnext) {
		if(line_ref.id == line_iter->id) {
			*line = line_iter;
			return offset;
		}
		int n, bytes;
		get_tangle_line_size(line_iter, &n, &bytes);
		offset += n;
		line_iter = line_iter->pnext;
	}
	assert(false);
	*line = NULL;
	return offset;
}

@otherwise_recurse_on_references_for_inserted_changes+=
else {
	for (size_t i = 0; i < kv_size(list->refs); i++) {
		LineRef line_ref = kv_A(list->refs, i);
		Line* parent_line;
		int parent_offset = get_line_from_ref(line_ref, &parent_line);
		int pre_offset = strlen(parent_line->prefix);
		tangle_inserted_bytes(offset + parent_offset, col+pre_offset, old, new, parent_line->parent_section);
	}
}

@changed_text_to_text+=
int offset = relative_offset_section(old_line);
tangle_inserted_bytes(offset, linecol, old, new, old_line->parent_section);

@define_functions+=
void tangle_inserted_lines(int offset, int old, int new, int old_byte, int new_byte, Section* section)
{
	@get_offset_to_parent_list
	@if_root_send_inserted_lines
	@otherwise_recurse_on_references_for_inserted_lines
}

@includes+=
#include "nvim/extmark.h"

@if_root_send_inserted_lines+=
SectionList* list = section->parent;
if(list->root) {
	buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, list->name);

	aco_save_T aco;
	aucmd_prepbuf(&aco, dummy_buf);
  extmark_splice(curbuf, 
      offset, 0,
      0, 0, (bcount_t)old_byte, 
      1, 0, (bcount_t)new_byte, kExtmarkUndo);
	changed_lines(offset+1, old, offset+1, new, true);
	aucmd_restbuf(&aco);
}

@otherwise_recurse_on_references_for_inserted_lines+=
else {
	for (size_t i = 0; i < kv_size(list->refs); i++) {
		LineRef line_ref = kv_A(list->refs, i);
		Line* parent_line;
		int parent_offset = get_line_from_ref(line_ref, &parent_line);
		tangle_inserted_lines(offset + parent_offset, old, new, old_byte, new_byte, parent_line->parent_section);
	}
}

@change_open_line+=
int offset = relative_offset_section(pl);
tangle_inserted_lines(offset, 0, 1, 0, 1, pl->parent_section);


@collect_lnum_to_delete_text+=
int offset = relative_offset_section(line);

@define_functions+=
void tangle_deleted_lines(int offset, int count, Section* section, int old_byte)
{
	@get_offset_to_parent_list
	@if_root_send_deleted_changes
	@otherwise_recurse_on_references_for_deleted_changes
}

@if_root_send_deleted_changes+=
SectionList* list = section->parent;
if(list->root) {
	buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, list->name);

	aco_save_T aco;
	aucmd_prepbuf(&aco, dummy_buf);
	deleted_lines_mark_tangle(offset+1, count, old_byte);
	aucmd_restbuf(&aco);
}

@define_functions+=
void deleted_lines_mark_tangle(linenr_T lnum, long count, int old_byte)
{
  bcount_t start_byte = ml_find_line_or_offset(curbuf, lnum, NULL, true);
  bcount_t new_byte = 0;
  int old_row, new_row;

	old_row = count;
	new_row = -(linenr_T)count + old_row;

  extmark_splice_impl(curbuf,
                      (int)lnum - 1, 0, start_byte,
                      old_row, 0, old_byte,
                      new_row, 0, new_byte, kExtmarkNoUndo);

  changed_lines(lnum, 0, lnum + (linenr_T)count, (linenr_T)(-count), true);
}

@otherwise_recurse_on_references_for_deleted_changes+=
else {
	for (size_t i = 0; i < kv_size(list->refs); i++) {
		LineRef line_ref = kv_A(list->refs, i);
		Line* parent_line;
		int parent_offset = get_line_from_ref(line_ref, &parent_line);
		tangle_deleted_lines(offset + parent_offset, count, parent_line->parent_section, old_byte);
	}
}

@change_line_delete_text+=
tangle_deleted_lines(offset, 1, cur_section, bytes);

@get_offset_of_removed_reference+=
int offset = relative_offset_section(line);

@change_line_delete_reference+=
tangle_deleted_lines(offset, n, cur_section, bytes);

@get_offset_of_old_line+=
int offset = relative_offset_section(old_line);

@get_old_line_size+=
int old_n, old_bytes;
get_tangle_line_size(old_line, &old_n, &old_bytes);

@changed_text_to_reference+=
tangle_inserted_lines(offset, 1, n, old_line->len, total, old_line->parent_section);

@change_reference_to_reference+=
if(old_n > 0 || new_n > 0) {
  tangle_inserted_lines(offset, old_n, new_n, old_bytes, new_bytes, old_line->parent_section);
}
