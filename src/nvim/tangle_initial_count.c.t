##tangle
@update_loc_data_tangle+=
tangle_update(buf);

@define_functions+=
void tangle_update(buf_T* buf)
{
	const char* name;
	SectionList* list;
	int n, total;
  map_foreach(&buf->sections, name, list, {
		tangle_get_count(buf, name, &n, &total);
  });
}

@define_functions+=
void tangle_get_count(buf_T* buf, const char* name, int* n, int* total)
{
	@check_if_count_is_memoized
	@otherwise_count_each_section

	*n = list->n;
	*total = list->total;
}

@section_list_data+=
int n;

@init_section_list+=
list->n = -1;
list->total = -1;

@check_if_count_is_memoized+=
if(!pmap_has(cstr_t)(&buf->sections, name)) {
	*n = 0;
	*total = 0;
	return;
}

SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
if(list->n != -1 && list->total != -1) {
	*n = list->n;
	*total = list->total;
	return;
}

@section_data+=
int n;

@otherwise_count_each_section+=
list->n = 0;
list->total = 0;
Section* section = list->phead;
while(section) {
	section->n = 0;
	section->total = 0;
	@count_section
	list->n += section->n;
	section = section->pnext;
}

@count_section+=
Line* line = section->head.pnext;
while(line != &section->tail) {
	@count_line
	line = line->pnext;
}

@count_line+=
if(line->type == TEXT) {
	section->n++;
	section->n += line->len;
} else if(line->type == REFERENCE) {
	int ref_n, ref_total;
	tangle_get_count(buf, line->name, &ref_n, &ref_total);

	int prefix_len = strlen(line->prefix);

	section->n += ref_n;
	section->total += ref_n*prefix_len + ref_total;
}
