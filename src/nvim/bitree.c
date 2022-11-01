// bitree.c: data structure for tangling
// 
// Based on B+ trees, this allows to do
// all operations in logarithmic time and
// with efficient cache usage.
// Bitree designates that there are two
// trees linked together where one is for
// the untangled code and the other is for
// the tangled code.

#include <inttypes.h>
#include <string.h>

#include "nvim/bitree.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bitree.c.generated.h"
#endif
