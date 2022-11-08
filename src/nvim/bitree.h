#ifndef NVIM_BITREE_H
#define NVIM_BITREE_H

#include <stdio.h>

#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"
#include "nvim/tangle_line.h"

#define BTREE_T 32

typedef struct bpnode_s bpnode;

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
};

typedef struct 
{
	bpnode* root;
	int total;
} bptree;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.h.generated.h"
#endif
#endif

