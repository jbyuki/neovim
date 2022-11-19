##tangle
@update_loc_data_tangle+=
tangle_update(buf);

@define_functions+=
void tangle_update(buf_T* buf)
{
	const char* name;
	SectionList* list;
  map_foreach(&buf->sections, name, list, {
		tangle_get_count(buf, name);
  });
}

@define_functions+=
int tangle_get_count(buf_T* buf, const char* name)
{
	@check_if_count_is_memoized
	@otherwise_count_each_section
	return list->n;
}

@section_list_data+=
int n;

@init_section_list+=
list->n = -1;

@check_if_count_is_memoized+=
if(!pmap_has(cstr_t)(&buf->sections, name)) {
	return 0;
}

SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
if(list->n != -1) {
	return list->n;
}

@section_data+=
int n;

@otherwise_count_each_section+=
list->n = 0;
Section* section = list->phead;
while(section) {
	section->n = 0;
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
} else if(line->type == REFERENCE) {
	section->n += tangle_get_count(buf, line->name);
}
