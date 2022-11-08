##tangle
@define_functions+=
int tangle_get_line_count(buf_T* buf, const char* root)
{
	assert(pmap_has(cstr_t)(&buf->sections, root));

	SectionList* list; 
	list = pmap_get(cstr_t)(&buf->sections, root);
	return 0;
}
