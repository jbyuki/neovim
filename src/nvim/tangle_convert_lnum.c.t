##tangle
@define_functions+=
int tangle_convert_lnum_to_untangled(buf_T* buf, const char* root, int lnum)
{
	int new_lnum;
	@search_for_line_with_lnum
	@reverse_lookup_line_in_btree
	return new_lnum;
}

@define_functions+=
Line* get_line_at_lnum_tangled(buf_T* buf, const char* name, int lnum)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	while(section) {
		if(lnum < section->n) {
			@look_for_lnum_in_section
		}
		lnum -= section->n;
		section = section->pnext;
	}

	return NULL;
}

@look_for_lnum_in_section+=
Line* line = section->head;
while(line) {
	if(line->type == TEXT) {
		if(lnum == 0) {
			return line;
		}
		lnum--;
	} else if(line->type == REFERENCE) {
		int count = tangle_get_count(buf, line->name);
		if(lnum < count) {
			return get_line_at_lnum_tangled(buf, line->name, lnum);
		}
		lnum -= count;
	}
	line = line->pnext;
}

@search_for_line_with_lnum+=
Line* line = get_line_at_lnum_tangled(buf, root, lnum);
assert(line);

@reverse_lookup_line_in_btree+=
new_lnum = tree_reverse_lookup(line);
