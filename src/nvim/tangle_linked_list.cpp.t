##tangle
@section_list_struct+=
typedef struct
{
  @section_list_data
} SectionList;

@section_list_data+=
Section* phead;
Section* ptail;

@define_functions_linked_list+=
static SectionList* sectionlist_init()
{
  SectionList* list = (SectionList*)xmalloc(sizeof(SectionList));
	@init_section_list

  list->phead = NULL;
  list->ptail = NULL;
  return list;
}

@section_data+=
struct section* pnext, *pprev;

@create_new_section+=
section->pnext = NULL;
section->pprev = NULL;

@define_functions_linked_list+=
static void sectionlist_push_back(SectionList* list, Section* section) 
{
  if(!list->ptail) {
    list->ptail = section;
    list->phead = section;
    return;
  }

	section->pprev = list->ptail;
  list->ptail->pnext = section;
  list->ptail = section;
}

static void sectionlist_push_front(SectionList* list, Section* section) 
{
  if(!list->phead) {
    list->phead = section;
    list->ptail = section;
    return;
  }

  section->pnext = list->phead;
	list->phead->pprev = section;
  list->phead = section;
}

@define_functions_linked_list+=
static void sectionlist_clear(SectionList* list) 
{
  Section* pcopy = list->phead;
  while(pcopy) {
    Section* temp = pcopy;
    pcopy = pcopy->pnext;
    @free_section
    xfree(temp);
  }

  list->phead = NULL;
  list->ptail = NULL;
}
