##bitree
@./bitree.h=
#ifndef NVIM_BITREE_H
#define NVIM_BITREE_H

#include <stdio.h>

#include "nvim/tangle_line.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"

@define_constants
@declare_struct
@struct
@define_inline

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.h.generated.h"
#endif
#endif

@./bitree.c=
// bitree.c: data structure for tangling
// 
// Based on B+ trees, this allows to do
// all operations in logarithmic time and
// with efficient cache usage.

#include <inttypes.h>
#include <string.h>

#include "nvim/bitree.h"

@includes
@variables

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "bitree.c.generated.h"
#endif

@define

@define_constants+=
#define BTREE_T 32

@variables+=
#define T BTREE_T

@includes+=
#include <stdbool.h>

@struct+=
struct bpnode_s
{
	bool leaf;
	bpnode* children[2*BTREE_T];
	bpnode* parent;
	uint8_t n;

	union {
		int counts[2*BTREE_T];
		Line keys[2*BTREE_T];
	};

	bpnode* left, *right;
};

typedef struct 
{
	bpnode* root;
	int total;
} bptree;

@define+=
bpnode* create_node()
{
	bpnode* node = (bpnode*)calloc(1, sizeof(bpnode));
	node->leaf = true;
	return node;
}

@define+=
bptree* create_tree()
{
	bptree* tree = (bptree*)malloc(sizeof(bptree));
	tree->total = 0;
	tree->root = create_node();
	return tree;
}

@define+=
void destroy_tree(bptree* tree)
{
	@delete_tree_recursively
	free(tree);
}

@define+=
void destroy_node(bpnode* node)
{
	if(!node->leaf) {
		for(int i=0; i<node->n; ++i) {
			destroy_node(node->children[i]);
		}
	}
	free(node);
}

@delete_tree_recursively+=
destroy_node(tree->root);

@define+=
Line* tree_insert(bptree* tree, int index, Line* value)
{
	if(tree->root->n == 2*T) {
		@create_new_root
		@split_root
	}
	tree->total++;
	return node_insert_nonfull(tree, tree->root, index, value);
}

@define+=
Line* node_insert_nonfull(bptree* tree, bpnode* node, int index, Line* value)
{
	if(node->leaf) {
		@insert_at_i
	} else {
		@search_for_children_node_to_insert
		if(node->children[j]->n == 2*T) {
			@split_current_node
		}
		@increase_counts_in_child
		@recurse_on_children_insert
	}
}

@define+=
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

@insert_at_i+=
for(int j=node->n; j>index; --j) {
	fix_line_links(&node->keys[j], &node->keys[j-1]);
	node->keys[j] = node->keys[j-1];
}
node->keys[index] = *value;
node->keys[index].parent = node;
node->n++;
return &node->keys[index];

@search_for_children_node_to_insert+=
int j=0;
while(index >= node->counts[j] && j < node->n-1) {
	index -= node->counts[j];
	j++;
}
assert(index <= node->counts[j]);

@define+=
void node_split(bpnode* child, int j, bpnode** pright)
{
	@create_right_sibling
	int right_count;
	@copy_keys_if_leaf
	@copy_children_and_counts_if_not

	@insert_right_as_child_in_parent
}

@includes+=
#include <assert.h>

@create_right_sibling+=
bpnode* right = create_node();
right->parent = child->parent;
right->leaf = child->leaf;

@copy_keys_if_leaf+=
if(child->leaf) {
	for(int i=0; i<T; ++i) {
		fix_line_links(&right->keys[i], &child->keys[i+T]);
		right->keys[i] = child->keys[i+T];
		right->keys[i].parent = right;
	}
	right->n = T;
	child->n = T;
	right_count = T;
}

@copy_children_and_counts_if_not+=
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


@insert_right_as_child_in_parent+=
bpnode* parent = child->parent;
for(int k=parent->n; k>j+1; --k) {
	parent->children[k] = parent->children[k-1];
}

for(int k=parent->n; k>j+1; --k) {
	parent->counts[k] = parent->counts[k-1];
}

parent->children[j+1] = right;

right->left = child;
right->right = child->right;
child->right = right;

parent->counts[j] = parent->counts[j] - right_count;
parent->counts[j+1] = right_count;

parent->n++;

if(pright) {
	*pright = right;
}

@split_current_node+=
bpnode* right;
node_split(node->children[j], j, &right);
if(index >= T) {
	j++;
	index -= T;
}

@increase_counts_in_child+=
node->counts[j]++;

@recurse_on_children_insert+=
return node_insert_nonfull(tree, node->children[j], index, value);

@create_new_root+=
bpnode* new_root = create_node();
new_root->leaf = false;
new_root->children[0] = tree->root;
new_root->counts[0] = tree->total;
new_root->n = 1;
tree->root->parent = new_root;

tree->root = new_root;

@split_root+=
node_split(new_root->children[0], 0, NULL);

@includes+=
#include <stdio.h>
#include <stdlib.h>

@define+=
void print_tree(bptree* tree)
{
	printf("Count: %d\n", tree->total);
	print_node(tree->root, 0);
}

@define+=
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

@define+=
Line* tree_delete(bptree* tree, int index)
{
	tree->total--;
	return delete_node_nonmin(tree, tree->root, index);
}


@define+=
Line* delete_node_nonmin(bptree* tree, bpnode* node, int index)
{
	@if_leaf_delete_key
	@otherwise_in_which_children_to_delete
}

@define+=
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

@if_leaf_delete_key+=
if(node->leaf) {
	delete_key(&node->keys[index]);
	for(int i=index; i<node->n-1; ++i) {
		fix_line_links(&node->keys[i], &node->keys[i+1]);
		node->keys[i] = node->keys[i+1];
	}
	node->n--;
	if(index == node->n) {
		bpnode* parent = node;
		@get_line_directly_to_the_right
	}
	return &node->keys[index];
}

@otherwise_in_which_children_to_delete+=
else {
	int j=0;
	@search_which_child_contains_index_to_delete
	@if_child_is_minimum_merge

	node->counts[j]--;
	return delete_node_nonmin(tree, node->children[j], index);
}

@search_which_child_contains_index_to_delete+=
while(j < node->n-1 && index >= node->counts[j]) {
	index -= node->counts[j];
	j++;
}

assert(index < node->counts[j]);

@if_child_is_minimum_merge+=
if(node->children[j]->n == T) {
	@try_to_borrow_from_left_sibling
	@try_to_borrow_from_right_sibling
	else {
		@otherwise_merge_with_left_sibling
		@otherwise_merge_with_right_sibling
		@if_only_child_remove_root
	}
}

@try_to_borrow_from_left_sibling+=
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
		right->keys[0].parent = right;
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

@try_to_borrow_from_right_sibling+=
else if(j+1 < node->n && node->children[j+1]->n > T) {
	node->counts[j+1]--;
	node->counts[j]++;

	bpnode* left = node->children[j];
	bpnode* right = node->children[j+1];

	if(left->leaf) {
		fix_line_links(&left->keys[left->n], &right->keys[0]);
		left->keys[left->n] = right->keys[0];
		left->keys[left->n].parent = left;
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

@otherwise_merge_with_left_sibling+=
if(j > 0) {
	bpnode* left = node->children[j-1];
	bpnode* right = node->children[j];

	@merge_right_to_left
	@remove_right_from_parent
	j = j-1;
}

@merge_right_to_left+=
int right_count = 0;
if(right->leaf) {
	for(int i=0; i<right->n; ++i) {
		fix_line_links(&left->keys[i+T], &right->keys[i]);
		left->keys[i+T] = right->keys[i];
		left->keys[i+T].parent = left;
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

@remove_right_from_parent+=
for(int i=j; i<node->n-1; ++i) {
	node->children[i] = node->children[i+1];
	node->counts[i] = node->counts[i+1];
}
index += node->counts[j-1];
node->counts[j-1] += right_count;
node->n--;

left->right = right->right;
if(right->right) {
	right->right->left = left;
}

free(right);

@otherwise_merge_with_right_sibling+=
else {
	bpnode* left = node->children[j];
	bpnode* right = node->children[j+1];

	@merge_right_to_left
	@remove_right_from_parent_from_left
}

@remove_right_from_parent_from_left+=
for(int i=j+1; i<node->n-1; ++i) {
	node->children[i] = node->children[i+1];
	node->counts[i] = node->counts[i+1];
}
node->counts[j] += right_count;
node->n--;

left->right = right->right;
if(right->right) {
	right->right->left = left;
}

free(right);

@if_only_child_remove_root+=
if(node->n == 1) {
	tree->root = tree->root->children[0];
	tree->root->parent = NULL;
	free(node);
	return delete_node_nonmin(tree, tree->root, index);
}

@define+=
Line* tree_lookup(bptree* tree, int index)
{
	return node_lookup(tree->root, index);
}

@define+=
Line* node_lookup(bpnode* node, int index)
{
	if(node->leaf) {
		return &node->keys[index];
	} else {
		int j=0;
		while(index >= node->counts[j] && j < node->n) {
			index -= node->counts[j];
			j++;
		}
		return node_lookup(node->children[j], index);
	}
}


@define+=
int tree_reverse_lookup(Line* line)
{
	bpnode* parent = line->parent;
	assert(parent);

	int offset = line - &parent->keys[0];
	assert(offset < parent->n);

	return node_reverse_lookup(parent, offset);
}

@define+=
int node_reverse_lookup(bpnode* node, int offset)
{
	if(!node->parent) {
		return offset;
	}

	else {
		bpnode* parent = node->parent;
		for(int i=0; i<parent->n; ++i) {
			if(parent->children[i] == node) {
				break;
			}
			offset += parent->counts[i];
		}
		return node_reverse_lookup(parent, offset);
	}
}

@define+=
Line* next_line(Line* line)
{
	bpnode* parent = line->parent;
	assert(parent);

	int offset = line - &parent->keys[0];
	offset++;
	if(offset == parent->n) {
		@get_line_directly_to_the_right
	}
	return &parent->keys[offset];
}

@get_line_directly_to_the_right+=
bpnode* right = parent->right;
if(right) {
	return &right->keys[0];
}
return NULL;

@define+=
Line* prev_line(Line* line)
{
	bpnode* parent = line->parent;
	assert(parent);

	int offset = line - &parent->keys[0];
	offset--;
	if(offset < 0) {
		@get_line_directly_to_the_left
	}
	return &parent->keys[offset];
}

@get_line_directly_to_the_left+=
bpnode* left = parent->left;
if(left) {
	return &left->keys[left->n-1];
}
return NULL;
