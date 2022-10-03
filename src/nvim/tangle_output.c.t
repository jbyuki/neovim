##tangle
@define_functions+=
void tangle_output(buf_T *tangle_view)
{
  @traverse_node_and_output
}

// @traverse_node_and_output+=
// for(auto& it : sections) {
	// @check_if_root_node
	// if(root) {
		// @open_file_to_output
		// @call_recursive_traverse_nodes_function
	// }
// }
