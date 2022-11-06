// bitree.c: data structure for tangling
// 
// Based on B+ trees, this allows to do
// all operations in logarithmic time and
// with efficient cache usage.

#include <inttypes.h>
#include <string.h>

#include "nvim/bitree.h"

#include <stdbool.h>

#include <assert.h>

#include <stdio.h>
#include <stdlib.h>

#define T BTREE_T


#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "bitree.c.generated.h"
#endif

bpnode* create_node()
{
	bpnode* node = (bpnode*)malloc(sizeof(bpnode));
	node->leaf = true;
	node->n = 0;
	node->parent = NULL;
	return node;
}

bptree* create_tree()
{
	bptree* tree = (bptree*)malloc(sizeof(bptree));
	tree->total = 0;
	tree->root = create_node();
	return tree;
}

void destroy_tree(bptree* tree)
{
	destroy_node(tree->root);

	free(tree);
}

void destroy_node(bpnode* node)
{
	if(!node->leaf) {
		for(int i=0; i<node->n; ++i) {
			destroy_node(node->children[i]);
		}
	}
	free(node);
}

Line* tree_insert(bptree* tree, int index, Line* value)
{
	if(tree->root->n == 2*T) {
		bpnode* new_root = create_node();
		new_root->leaf = false;
		new_root->children[0] = tree->root;
		new_root->counts[0] = tree->total;
		new_root->n = 1;
		tree->root->parent = new_root;

		tree->root = new_root;

		node_split(new_root->children[0], 0, NULL);

	}
	tree->total++;
	return node_insert_nonfull(tree, tree->root, index, value);
}

Line* node_insert_nonfull(bptree* tree, bpnode* node, int index, Line* value)
{
	if(node->leaf) {
		for(int j=node->n; j>index; --j) {
			fix_line_links(&node->keys[j], &node->keys[j-1]);
			node->keys[j] = node->keys[j-1];
		}
		node->keys[index] = *value;
		node->n++;
		return &node->keys[index];

	} else {
		int j=0;
		while(index >= node->counts[j] && j < node->n-1) {
			index -= node->counts[j];
			j++;
		}
		assert(index <= node->counts[j]);

		if(node->children[j]->n == 2*T) {
			bpnode* right;
			node_split(node->children[j], j, &right);
			if(index >= T) {
				j++;
				index -= T;
			}

		}
		node->counts[j]++;

		return node_insert_nonfull(tree, node->children[j], index, value);

	}
}

static inline void fix_line_links(Line* to, Line* from)
	FUNC_ATTR_ALWAYS_INLINE
{
	if(from->pprev) {
		from->pprev->pnext = to;
	}

	if(from->pnext) {
		from->pnext->pprev = to;
	}
}

void node_split(bpnode* child, int j, bpnode** pright)
{
	bpnode* right = create_node();
	right->parent = child->parent;
	right->leaf = child->leaf;

	int right_count;
	if(child->leaf) {
		for(int i=0; i<T; ++i) {
			fix_line_links(&right->keys[i], &child->keys[i+T]);
			right->keys[i] = child->keys[i+T];
		}
		right->n = T;
		child->n = T;
		right_count = T;
	}

	else {
		for(int i=0; i<T; ++i) {
			right->children[i] = child->children[i+T];
			right->children[i]->parent = right;
		}

		right_count = 0;
		for(int i=0; i<T; ++i) {
			right->counts[i] = child->counts[i+T];
			right_count += right->counts[i];
		}
		right->n = T;
		child->n = T;
	}



	bpnode* parent = child->parent;
	for(int k=parent->n; k>j+1; --k) {
		parent->children[k] = parent->children[k-1];
	}

	for(int k=parent->n; k>j+1; --k) {
		parent->counts[k] = parent->counts[k-1];
	}

	parent->children[j+1] = right;

	parent->counts[j] = parent->counts[j] - right_count;
	parent->counts[j+1] = right_count;

	parent->n++;

	if(pright) {
		*pright = right;
	}

}

void print_tree(bptree* tree)
{
	printf("Count: %d\n", tree->total);
	print_node(tree->root, 0);
}

void print_node(bpnode* node, int indent)
{
	if(node->leaf) {
		for(int j=0; j<indent; ++j) {
			printf(".");
		}
		printf("[%p]\n", node);
		for(int j=0; j<indent; ++j) {
			printf(".");
		}
		printf("parent [%p]\n", node->parent);
		for(int i=0; i<node->n; ++i) {
			for(int j=0; j<indent; ++j) {
				printf(" ");
			}
			printf("key\n");
		}
	} else {
		for(int j=0; j<indent; ++j) {
			printf(".");
		}
		printf("[%p]\n", node);
		for(int j=0; j<indent; ++j) {
			printf(".");
		}
		printf("parent [%p]\n", node->parent);

		for(int i=0; i<node->n; ++i) {
			print_node(node->children[i], indent+1);
		}
	}
}

void tree_delete(bptree* tree, int index)
{
	delete_node_nonmin(tree, tree->root, index);
	tree->total--;
}


void delete_node_nonmin(bptree* tree, bpnode* node, int index)
{
	if(node->leaf) {
		delete_key(&node->keys[index]);
		for(int i=index; i<node->n-1; ++i) {
			fix_line_links(&node->keys[i], &node->keys[i+1]);
			node->keys[i] = node->keys[i+1];
		}
		node->n--;
	}

	else {
		int j=0;
		while(j < node->n-1 && index >= node->counts[j]) {
			index -= node->counts[j];
			j++;
		}

		assert(index < node->counts[j]);

		if(node->children[j]->n == T) {
			if(j > 0 && node->children[j-1]->n > T) {
				node->counts[j-1]--;
				node->counts[j]++;

				bpnode* left = node->children[j-1];
				bpnode* right = node->children[j];

				if(right->leaf) {
					for(int i=right->n-1; i>=0; --i) {
						fix_line_links(&right->keys[i+1], &right->keys[i]);
						right->keys[i+1] = right->keys[i];
					}

					fix_line_links(&right->keys[0], &left->keys[left->n-1]);
					right->keys[0] = left->keys[left->n-1];
				} else {
					for(int i=right->n-1; i>=0; --i) {
						right->children[i+1] = right->children[i];
						right->counts[i+1] = right->counts[i];
					}
					right->children[0] = left->children[left->n-1];
					right->counts[0] = left->counts[left->n-1];
				}
				
				left->n--;
				right->n++;
				index++;
			}

			else if(j+1 < node->n && node->children[j+1]->n > T) {
				node->counts[j+1]--;
				node->counts[j]++;

				bpnode* left = node->children[j];
				bpnode* right = node->children[j+1];

				if(left->leaf) {
					fix_line_links(&left->keys[left->n], &right->keys[0]);
					left->keys[left->n] = right->keys[0];
					for(int i=0; i<right->n-1; ++i) {
						fix_line_links(&right->keys[i], &right->keys[i+1]);
						right->keys[i] = right->keys[i+1];
					}
				} else {
					left->children[left->n] = right->children[0];
					left->counts[left->n] = right->counts[0];

					for(int i=0; i<right->n-1; ++i) {
						right->children[i] = right->children[i+1];
						right->counts[i] = right->counts[i+1];
					}
				}

				left->n++;
				right->n--;
			}

			else {
				if(j > 0) {
					bpnode* left = node->children[j-1];
					bpnode* right = node->children[j];

					int right_count = 0;
					if(right->leaf) {
						for(int i=0; i<right->n; ++i) {
							fix_line_links(&left->keys[i+T], &right->keys[i]);
							left->keys[i+T] = right->keys[i];
						}
						right_count = T;
					} else {
						for(int i=0; i<right->n; ++i) {
							left->counts[i+T] = right->counts[i];
							left->children[i+T] = right->children[i];
							left->children[i+T]->parent = left;
							right_count += right->counts[i];
						}
					}
					left->n += T;

					for(int i=j; i<node->n-1; ++i) {
						node->children[i] = node->children[i+1];
						node->counts[i] = node->counts[i+1];
					}
					index += node->counts[j-1];
					node->counts[j-1] += right_count;
					node->n--;

					free(right);

					j = j-1;
				}

				else {
					bpnode* left = node->children[j];
					bpnode* right = node->children[j+1];

					int right_count = 0;
					if(right->leaf) {
						for(int i=0; i<right->n; ++i) {
							fix_line_links(&left->keys[i+T], &right->keys[i]);
							left->keys[i+T] = right->keys[i];
						}
						right_count = T;
					} else {
						for(int i=0; i<right->n; ++i) {
							left->counts[i+T] = right->counts[i];
							left->children[i+T] = right->children[i];
							left->children[i+T]->parent = left;
							right_count += right->counts[i];
						}
					}
					left->n += T;

					for(int i=j+1; i<node->n-1; ++i) {
						node->children[i] = node->children[i+1];
						node->counts[i] = node->counts[i+1];
					}
					node->counts[j] += right_count;
					node->n--;

					free(right);

				}

				if(node->n == 1) {
					tree->root = tree->root->children[0];
					tree->root->parent = NULL;
					free(node);
					delete_node_nonmin(tree, tree->root, index);
					return;
				}

				// @define+=
				// int tree_lookup(bptree* tree, int index)
				// {
					// return node_lookup(tree->root, index);
				// }

				// @define+=
				// int node_lookup(bpnode* node, int index)
				// {
					// if(node->leaf) {
						// return node->keys[index];
					// } else {
						// int j=0;
						// while(index >= node->counts[j] && j < node->n) {
							// index -= node->counts[j];
							// j++;
						// }
						// return node_lookup(node->children[j], index);
					// }
				// }


				// @define+=
				// int tree_reverse_lookup(bpnode* node, int offset)
				// {
					// if(!node->parent) {
						// return offset;
					// }

					// else {
						// bpnode* parent = node->parent;
						// for(int i=0; i<parent->n; ++i) {
							// if(parent->children[i] == node) {
								// break;
							// }
							// offset += parent->counts[i];
						// }
						// return tree_reverse_lookup(parent, offset);
					// }
				// }
			}
		}


		node->counts[j]--;
		delete_node_nonmin(tree, node->children[j], index);
	}

}

static inline void delete_key(Line* line)
	FUNC_ATTR_ALWAYS_INLINE
{
	if(line->pprev) {
		line->pprev->pnext = line->pnext;
	}

	if(line->pnext) {
		line->pnext->pprev = line->pprev;
	}
}


