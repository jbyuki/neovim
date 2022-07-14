// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"

#include "nvim/message.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

void attach_tangle(buf_T *buf) 
{
  semsg(_("Tangle activated!"));
}

void deattach_tangle(buf_T *buf) 
{
  semsg(_("Tangle deactivated!"));
}

