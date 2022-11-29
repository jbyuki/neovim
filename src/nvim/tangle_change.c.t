##tangle
@define_functions+=
void tangle_inserted_bytes(linenr_T lnum, colnr_T col, int old, int new, Line* line)
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
		offset += get_tangle_line_size(line_iter);
		line_iter = line_iter->pprev;
	}
	return offset;
}

@get_offset_to_parent_list+=
int offset = lnum;
Section* section = line->parent_section;
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
		offset += get_tangle_line_size(line_iter);
		line_iter = line_iter->pprev;
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
		offset += get_line_from_ref(line_ref, &parent_line);
		int pre_offset = strlen(parent_line->prefix);
		tangle_inserted_bytes(offset, col+pre_offset, old, new, parent_line);
	}
}

@changed_text_to_text+=
int offset = relative_offset_section(old_line);
tangle_inserted_bytes(offset, linecol, old, new, old_line);
