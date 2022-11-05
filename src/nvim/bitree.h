#ifndef NVIM_BITREE_H
#define NVIM_BITREE_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/garray.h"
#include "nvim/pos.h"
#include "nvim/types.h"

#define BTREE_T 20

typedef struct bpnode_s bpnode;

typedef struct sectionheader_s sectionheader;

struct bpnode_s
{
	bool leaf;
	bpnode* children[2*BTREE_T];
	bpnode* parent;
	int n;

	union {
		int counts[2*BTREE_T];
		int keys[2*BTREE_T];
	};

	sectionheader* pheader;
	bpnode* prev;
};

typedef struct 
{
	bpnode* root;
	int total;
} bptree;

struct sectionheader_s 
{
	int size;
	sectionheader* prev, *next;
	bpnode* first;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.h.generated.h"
#endif
#endif

