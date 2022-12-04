##tangle
@define_functions+=
int find_first_parent(Line* line, int lnum, SectionList** root_section_list)
{
	@go_backward_to_section_list
	@if_root_return_section_list_and_lnum
	@otherwise_recurse_on_first_ref_line
}

@go_backward_to_section_list+=
Section* section = line->parent_section;
SectionList* section_list = section->parent;
section = section->pprev;
while(section) {
	lnum += section->n;
	section = section->pprev;
}

@if_root_return_section_list_and_lnum+=
if(section_list->root) {
	*root_section_list = section_list;
	return lnum;
}

@otherwise_recurse_on_first_ref_line+=
else {
	if(kv_size(section_list->refs) > 0) {
		LineRef line_ref = kv_A(section_list->refs, 0);
		Line* parent_line;
		int offset = get_line_from_ref(line_ref, &parent_line);
		return lnum + find_first_parent(parent_line, offset, root_section_list);
	} else {
		return -1;
	}
}

@define_functions+=
void get_tangle_buf_line(buf_T* parent_buf, Line* line, int* lnum, buf_T** tangle_buf)
{
	SectionList* list;
	int offset = relative_offset_section(line);
	*lnum = find_first_parent(line, offset, &list);
	buf_T* buf = pmap_get(cstr_t)(&parent_buf->tgl_bufs, list->name);
	*tangle_buf = buf;
}
