##tangle
@define_functions+=
void tangle_output(buf_T *tangle_view)
{
  @traverse_node_and_output
}

@traverse_node_and_output+=
for(int i=0; i<kv_size(section_names); ++i) {
	@check_if_root_node
	if(root) {
		@call_recursive_traverse_nodes_function
	}
}

@global_variables+=
static PMap(cstr_t) is_root = MAP_INIT;

@parse_variables+=
pmap_clear(cstr_t)(&is_root);

@create_new_section+=
if(op == 0) {
  pmap_put(cstr_t)(&is_root, name, NULL);
}

@check_if_root_node+=
char* name = kv_A(section_names, i);
bool root = pmap_has(cstr_t)(&is_root, name);

@define_functions+=
static void traverseNode(buf_T* tangle_view, char* prefix, char* name, int* line_num)
{
	@get_section
	@loop_through_section_parts
}

@call_recursive_traverse_nodes_function+=
int line_num = 0;
traverseNode(tangle_view, "", name, &line_num);

@get_section+=
if(!pmap_has(cstr_t)(&sections, name)) {
  return;
}

@loop_through_section_parts+=
SectionList* list = pmap_get(cstr_t)(&sections, name);
for(Section* pcopy = list->phead; pcopy; pcopy = pcopy->pnext) {
  for(int i=0; i<kv_size(pcopy->lines); ++i) {
    Line l = kv_A(pcopy->lines, i);
		switch(l.type) {
		@output_line
		default: break;
		}
  }
}

@output_line+=
case TEXT: 
{
  size_t len = strlen(prefix) + strlen(l.str);
  char* line = (char*)xmalloc(len+1);
  STRCPY(line, prefix);
  STRCAT(line, l.str);

  ml_append_buf(tangle_view, *line_num, line, (colnr_T)0, false);
  line_num++;
  break;
}

@output_line+=
case REFERENCE:
{
  size_t len = strlen(prefix) + strlen(l.prefix);
  char* new_prefix = (char*)xmalloc(len+1);
  STRCPY(new_prefix, prefix);
  STRCAT(new_prefix, l.prefix);
  traverseNode(tangle_view, new_prefix, l.str, line_num);
  xfree(new_prefix);
  break;
}
