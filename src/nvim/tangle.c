// tangle.c: code for tangling

#include <inttypes.h>
#include <string.h>

#include "nvim/tangle.h"
#include "nvim/garray.h"

#include "nvim/message.h"

#include "nvim/buffer.h"
#include "nvim/option.h"

#include "nvim/tangle_utils.h"

#include "nvim/vim.h"

#include "nvim/map.h"

#include <assert.h>

#include "klib/kvec.h"

#include "nvim/bitree.h"



#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tangle.c.generated.h"
#endif

static SectionList* sectionlist_init(const char* name)
{
  SectionList* list = (SectionList*)xcalloc(1, sizeof(SectionList));
	list->root = false;

	list->n = -1;
	list->total = -1;

	list->name = name;

  list->phead = NULL;
  list->ptail = NULL;
  return list;
}

static void sectionlist_push_back(SectionList* list, Section* section) 
{
	section->parent = list;
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
	section->parent = list;
  if(!list->phead) {
    list->phead = section;
    list->ptail = section;
    return;
  }

  section->pnext = list->phead;
	list->phead->pprev = section;
  list->phead = section;
}

static void sectionlist_clear(SectionList* list) 
{
  Section* pcopy = list->phead;
  while(pcopy) {
    Section* temp = pcopy;
    pcopy = pcopy->pnext;
    temp->head.pnext = NULL;
    temp->tail.pprev = NULL;

    xfree(temp);
  }

	kv_destroy(list->refs);
  list->phead = NULL;
  list->ptail = NULL;
}

static void sectionlist_remove(Section* section)
{
	SectionList* list = section->parent;

	if(section->pprev) {
		section->pprev->pnext = section->pnext;
	} else {
		list->phead = list->phead->pnext;
	}

	if(section->pnext) {
		section->pnext->pprev = section->pprev;
	} else {
		list->ptail = list->ptail->pprev;
	}

	xfree(section);
}

void attach_tangle(buf_T *buf) 
{
  // semsg(_("Tangle activated!"));
  tangle_parse(buf);

	tangle_update(buf);

	kvec_t(cstr_t) root_names = KV_INITIAL_VALUE;
	const char* name;
	buf_T* pbuf;
	map_foreach(&buf->tgl_bufs, name, pbuf, {
		kv_push(root_names, name);
	});

	for(int i=0; i<kv_size(root_names); ++i) {
		const char* root_name = kv_A(root_names, i);

		buf_T* view_buf = buflist_new(root_name, NULL, 1L, BLN_DUMMY);
		pmap_put(cstr_t)(&buf->tgl_bufs, name, view_buf);
		view_buf->parent_tgl = buf;

		apply_autocmds(EVENT_BUFTANGLEPOST, NULL, root_name, false, view_buf);
	}
}

void deattach_tangle(buf_T *buf) 
{
  // semsg(_("Tangle deactivated!"));
}

// Reimplement "ml_find_line_or_offset" but for tangled buffers
long tangle_find_line_or_offset(buf_T *buf, linenr_T lnum, long *offp, bool no_ff)
{
	if(lnum > 0) {
		return get_bytes_at_lnum_tangled(buf->parent_tgl, buf->b_fname, lnum-1, 0);

	} else {
		return get_lnum_at_bytes_tangled(buf->parent_tgl, buf->b_fname, *offp, 0);
	}
}

int get_bytes_at_lnum_tangled(buf_T* buf, const char* name, int lnum, int prefix_len)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	int bytes = 0;
	while(section) {
		if(lnum < section->n) {
			Line* line = section->head.pnext;
			while(line != &section->tail) {
				if(line->type == TEXT) {
					if(lnum == 0) {
						return bytes;
					}
					lnum--;
					bytes += prefix_len + line->len;
				} else if(line->type == REFERENCE) {
					int count, total;
					tangle_get_count(buf, line->name, &count, &total);
					int ref_prefix_len = prefix_len+strlen(line->prefix);
					if(lnum < count) {
						return bytes + get_bytes_at_lnum_tangled(buf, line->name, lnum, ref_prefix_len);
					}
					lnum -= count;
					bytes += count * ref_prefix_len + total;
				}
				line = line->pnext;
			}

		}
		lnum -= section->n;
		lnum -= section->n*prefix_len + section->total;
		section = section->pnext;
	}
	return bytes;
}

int get_lnum_at_bytes_tangled(buf_T* buf, const char* name, int bytes, int prefix_len)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	int lnum = 0;
	while(section) {
		int section_bytes = section->n*prefix_len + section->total;
		if(bytes < section_bytes) {
			Line* line = section->head.pnext;
			while(line != &section->tail) {
				if(line->type == TEXT) {
					if(bytes < prefix_len + line->len) {
						return lnum;
					}
					lnum++;
					bytes -= prefix_len + line->len;
				} else if(line->type == REFERENCE) {
					int count, total;
					tangle_get_count(buf, line->name, &count, &total);
					int ref_prefix_len = prefix_len+strlen(line->prefix);
					int ref_bytes = count * ref_prefix_len + total;

					if(bytes < ref_bytes) {
						return lnum + get_lnum_at_bytes_tangled(buf, line->name, bytes, ref_prefix_len);
					}
					lnum += count;
					bytes -= ref_bytes;
				}
				line = line->pnext;
			}

		}
		lnum += section->n;
		bytes -= section_bytes;
		section = section->pnext;
	}
	return bytes;
}

void tangle_inserted_bytes(linenr_T lnum, colnr_T col, int old, int new, Line* line)
{
	int offset = lnum;
	Section* section = line->parent_section;
	Section* section_iter = section->pprev;
	while(section_iter) {
		offset += section_iter->n;
		section_iter = section_iter->pprev;
	}

	SectionList* list = section->parent;
	if(list->root) {
		buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, list->name);

		aco_save_T aco;
		aucmd_prepbuf(&aco, dummy_buf);
		inserted_bytes(offset+1, col, old, new);
		aucmd_restbuf(&aco);
	}

	else {
		for (size_t i = 0; i < kv_size(list->refs); i++) {
			LineRef line_ref = kv_A(list->refs, i);
			Line* parent_line;
			offset += get_line_from_ref(line_ref, &parent_line);
			int pre_offset = strlen(parent_line->prefix);
			tangle_inserted_bytes(offset, col+pre_offset, old, new, parent_line);
		}
	}

}

int relative_offset_section(Line* line)
{
	int offset = 0;
	Line* line_iter = line->pprev;
	while(line_iter->pprev) {
		int n, bytes;
		get_tangle_line_size(line_iter, &n, &bytes);
		offset += n;
		line_iter = line_iter->pprev;
	}
	return offset;
}

int get_line_from_ref(LineRef line_ref, Line** line)
{
	Section* section = line_ref.section;
	int offset = 0;
	Line* line_iter = section->head.pnext;
	while(line_iter->pnext) {
		if(line_ref.id == line_iter->id) {
			*line = line_iter;
			return offset;
		}
		int n, bytes;
		get_tangle_line_size(line_iter, &n, &bytes);
		offset += n;
		line_iter = line_iter->pnext;
	}
	assert(false);
	*line = NULL;
	return offset;
}

void tangle_inserted_lines(linenr_T lnum, int old, int new, Line* line)
{
	int offset = lnum;
	Section* section = line->parent_section;
	Section* section_iter = section->pprev;
	while(section_iter) {
		offset += section_iter->n;
		section_iter = section_iter->pprev;
	}

	SectionList* list = section->parent;
	if(list->root) {
		buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, list->name);

		aco_save_T aco;
		aucmd_prepbuf(&aco, dummy_buf);
		changed_lines(offset+1, old, offset+1, new, true);
		extmark_splice(curbuf, offset, 0,
				0, 0, 0, 1, 0, 1, kExtmarkUndo);
		aucmd_restbuf(&aco);
	}

	else {
		for (size_t i = 0; i < kv_size(list->refs); i++) {
			LineRef line_ref = kv_A(list->refs, i);
			Line* parent_line;
			offset += get_line_from_ref(line_ref, &parent_line);
			tangle_inserted_lines(offset, old, new, parent_line);
		}
	}

}

int tangle_convert_lnum_to_untangled(buf_T* buf, const char* root, int lnum, char* prefix)
{
	int new_lnum;
	Line* line = get_line_at_lnum_tangled(buf, root, lnum, prefix);
	assert(line);

	new_lnum = tree_reverse_lookup(line);
	return new_lnum;
}

Line* get_line_at_lnum_tangled(buf_T* buf, const char* name, int lnum, char* prefix)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	while(section) {
		if(lnum < section->n) {
			Line* line = section->head.pnext;
			while(line != &section->tail) {
				if(line->type == TEXT) {
					if(lnum == 0) {
						return line;
					}
					lnum--;
				} else if(line->type == REFERENCE) {
					int count, total;
					tangle_get_count(buf, line->name, &count, &total);
					if(lnum < count) {
						STRCAT(prefix, line->prefix);
						return get_line_at_lnum_tangled(buf, line->name, lnum, prefix);
					}
					lnum -= count;
				}
				line = line->pnext;
			}

		}
		lnum -= section->n;
		section = section->pnext;
	}

	return NULL;
}

Line* get_current_tangle_line()
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	Line* line = tree_lookup(curbuf->tgl_tree, lnum-1);

	return line;
}

void update_current_tangle_line(Line* old_line, int rel, int linecol, int old, int new)
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	char *line = ml_get(lnum + rel);
	size_t linelen = strlen(line) + 1;  // length of old line including NUL

	char* fp = strnwfirst(line);
	char* lp = strnwlast(line);

	Line new_line = *old_line;
	if(fp == NULL) {
		new_line.type = TEXT;
	} else if(*fp == '@') {
	  if(*(fp+1) != '@') {
	    if(*(fp+1) == '=' || *(fp+1) == '+' || *(fp+1) == '-') {
				new_line.type = SECTION;
	    } else {
				new_line.type = REFERENCE;
	    }
	  } else {
			new_line.type = TEXT;
	  }
	} else {
		new_line.type = TEXT;
	}


	if(old_line->type == TEXT) {
		if(new_line.type == TEXT) {
			// Nothing to do
			new_line.len = strlen(line)+1;
			update_count_recursively(old_line->parent_section, 0, new_line.len - old_line->len);

			int offset = relative_offset_section(old_line);
			tangle_inserted_bytes(offset, linecol, old, new, old_line);

		} else if(new_line.type == REFERENCE) {
			size_t len = fp - line;
			char* prefix = xmalloc(len+1);
			STRNCPY(prefix, line, len);
			prefix[len] = '\0';

			len = (lp+1)-(fp+1);
			char* name = xmalloc(len+1);
			STRNCPY(name, fp+1, len);
			name[len] = '\0';


			new_line.name = name;
			new_line.prefix = prefix;

			int n, total;
			tangle_get_count(curbuf, name, &n, &total);
			update_count_recursively(old_line->parent_section, -1 + n, -old_line->len + total);

			SectionList* list = get_section_list(&curbuf->sections, name);
			LineRef line_ref;
			line_ref.section = new_line.parent_section;
			line_ref.id = new_line.id;
			line_ref.prefix_len = strlen(prefix);
			kv_push(list->refs, line_ref);


		} else if(new_line.type == SECTION) {
			buf_T* buf = curbuf;
			Section* cur_section;
			int op;
			switch(*(fp+1)) {
			case '+': op = 1; break;
			case '-': op = 2; break;
			default: op = 0; break;
			}

			// fp  fp+1 ... lp
			// @    +   
			// len = 0 if fp+1 == lp
			size_t len = lp - (fp+1);
			char* name = xmalloc(len + 1);
			STRNCPY(name, fp+2, len);
			name[len] = '\0';

			Section* section = (Section*)xcalloc(1, sizeof(Section));

			cur_section = section;

			SectionList* list;
			if(op == 1 || op == 2) {
				list = get_section_list(&buf->sections, name);
			  if(op == 1) {
			    sectionlist_push_back(list, section);

			  } else { /* op == 2 */
			    sectionlist_push_front(list, section);

			  }
			}

			else {
			  if(pmap_has(cstr_t)(&buf->sections, name)) {
			    list = pmap_get(cstr_t)(&buf->sections, name);
			  } else {
			    list = sectionlist_init(name);
			    pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
			    pmap_put(cstr_t)(&buf->tgl_bufs, xstrdup(name), NULL);
			  }


			  sectionlist_clear(list);
				list->root = true;

			  sectionlist_push_back(list, section);
			}


			if(list->n == -1 || list->total == -1) {
				list->n = 0;
				list->total = 0;
			}


			new_line.name = name;
			new_line.pnext = NULL;
			new_line.pprev = NULL;

			Line* next_l = old_line->pnext;
			Line* next_line = next_l;
			while(next_line && next_line->pnext) {
				next_line->parent_section = section;
				next_line = next_line->pnext;
			}

			next_line = next_l;

			int removed = 0;
			int removed_bytes = 0;

			while(next_line && next_line->pnext) {
				int n, bytes;
				get_tangle_line_size(next_line, &n, &bytes);
				removed += n;
				removed_bytes += bytes;
				next_line = next_line->pnext;
			}

			next_line = next_l;

			Section* old_section = old_line->parent_section;
			while(next_line && next_line->pnext) {
				if(next_line->type == REFERENCE) {
					SectionList* ref_list = get_section_list(&curbuf->sections, next_line->name);
					LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
					remove_ref(ref_list, old_ref);
					LineRef line_ref;
					line_ref.section = section;
					line_ref.id = next_line->id;
					line_ref.prefix_len = strlen(next_line->prefix);
					kv_push(ref_list->refs, line_ref);
				}
				next_line = next_line->pnext;
			}

			int old_n, old_bytes;
			get_tangle_line_size(old_line, &old_n, &old_bytes);
			update_count_recursively(old_line->parent_section, 
				-old_n - removed, 
				-old_bytes - removed_bytes
			);

			update_count_recursively(section, removed, removed_bytes);

			section->head.pnext = old_line->pnext;
			section->tail.pprev = old_line->parent_section->tail.pprev;
			old_line->parent_section->tail.pprev = old_line->pprev;


		}
	}


	else if(old_line->type == REFERENCE) {
		if(new_line.type == TEXT) {
			int n, bytes;
			get_tangle_line_size(old_line, &n, &bytes);
			update_count_recursively(old_line->parent_section, -n+1, -bytes+new_line.len);

			{
			SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);
			LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
			remove_ref(old_list, line_ref);
			}


		} else if(new_line.type == REFERENCE) {
			size_t len = fp - line;
			char* prefix = xmalloc(len+1);
			STRNCPY(prefix, line, len);
			prefix[len] = '\0';

			len = (lp+1)-(fp+1);
			char* name = xmalloc(len+1);
			STRNCPY(name, fp+1, len);
			name[len] = '\0';


			new_line.name = name;
			new_line.prefix = prefix;

			int old_n, new_n;
			int old_bytes, new_bytes;
			get_tangle_line_size(old_line, &old_n, &old_bytes);
			get_tangle_line_size(&new_line, &new_n, &new_bytes);
			update_count_recursively(old_line->parent_section, -old_n + new_n, -old_bytes + new_bytes);

			{
			SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);
			LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
			remove_ref(old_list, line_ref);
			}

			SectionList* list = get_section_list(&curbuf->sections, name);
			LineRef line_ref;
			line_ref.section = new_line.parent_section;
			line_ref.id = new_line.id;
			line_ref.prefix_len = strlen(prefix);
			kv_push(list->refs, line_ref);


		} else if(new_line.type == SECTION) {
			buf_T* buf = curbuf;
			Section* cur_section;
			int op;
			switch(*(fp+1)) {
			case '+': op = 1; break;
			case '-': op = 2; break;
			default: op = 0; break;
			}

			// fp  fp+1 ... lp
			// @    +   
			// len = 0 if fp+1 == lp
			size_t len = lp - (fp+1);
			char* name = xmalloc(len + 1);
			STRNCPY(name, fp+2, len);
			name[len] = '\0';

			Section* section = (Section*)xcalloc(1, sizeof(Section));

			cur_section = section;


			new_line.name = name;
			new_line.pnext = NULL;
			new_line.pprev = NULL;
			new_line.parent_section = section;

			Line* next_l = next_line(old_line);

			Line* next_line = next_l;
			while(next_line && next_line->pnext) {
				next_line->parent_section = section;
				next_line = next_line->pnext;
			}

			next_line = next_l;

			int removed = 0;
			int removed_bytes = 0;

			while(next_line && next_line->pnext) {
				int n, bytes;
				get_tangle_line_size(next_line, &n, &bytes);
				removed += n;
				removed_bytes += bytes;
				next_line = next_line->pnext;
			}

			{
				SectionList* ref_list = get_section_list(&curbuf->sections, old_line->name);
				LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
				remove_ref(ref_list, line_ref);
			}

			next_line = next_l;

			Section* old_section = old_line->parent_section;
			while(next_line && next_line->pnext) {
				if(next_line->type == REFERENCE) {
					SectionList* ref_list = get_section_list(&curbuf->sections, next_line->name);
					LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
					remove_ref(ref_list, old_ref);
					LineRef line_ref;
					line_ref.section = section;
					line_ref.id = next_line->id;
					line_ref.prefix_len = strlen(next_line->prefix);
					kv_push(ref_list->refs, line_ref);
				}
				next_line = next_line->pnext;
			}

			int old_n, old_bytes;
			get_tangle_line_size(old_line, &old_n, &old_bytes);
			update_count_recursively(old_line->parent_section, 
				-old_n - removed, 
				-old_bytes - removed_bytes
			);

			section->head.pnext = old_line->pnext;
			section->tail.pprev = old_line->parent_section->tail.pprev;
			old_line->parent_section->tail.pprev = old_line->pprev;


			SectionList* list;
			if(op == 1 || op == 2) {
				list = get_section_list(&buf->sections, name);
			  if(op == 1) {
			    sectionlist_push_back(list, section);

			  } else { /* op == 2 */
			    sectionlist_push_front(list, section);

			  }
			}

			else {
			  if(pmap_has(cstr_t)(&buf->sections, name)) {
			    list = pmap_get(cstr_t)(&buf->sections, name);
			  } else {
			    list = sectionlist_init(name);
			    pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
			    pmap_put(cstr_t)(&buf->tgl_bufs, xstrdup(name), NULL);
			  }


			  sectionlist_clear(list);
				list->root = true;

			  sectionlist_push_back(list, section);
			}


			if(list->n == -1 || list->total == -1) {
				list->n = 0;
				list->total = 0;
			}

			update_count_recursively(section, removed, removed_bytes);


			if(op == 0) {
				buf_T* view_buf = buflist_new(name, NULL, 1L, BLN_NEW | BLN_NOOPT);
				pmap_put(cstr_t)(&curbuf->tgl_bufs, name, view_buf);
				view_buf->parent_tgl = curbuf;
			}


		}
	}

	else if(old_line->type == SECTION) {
		if(new_line.type == TEXT) {
			Line* next_l = next_line(old_line);
			Line* prev_l = prev_line(old_line, &curbuf->first_line);

			Section* prev_section = prev_l->parent_section;

			new_line.parent_section = prev_section;

			Line* line_iter = next_l;
			while(line_iter->pnext) {
				line_iter->parent_section = prev_section;
				line_iter = line_iter->pnext;
			}


			line_iter = next_l;
			while(line_iter->pnext) {
				if(line_iter->type == REFERENCE) {
					SectionList* ref_list = get_section_list(&curbuf->sections, line_iter->name);
					LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
					remove_ref(ref_list, old_ref);
					LineRef line_ref;
					line_ref.section = prev_section;
					line_ref.id = line_iter->id;
					line_ref.prefix_len = strlen(line_iter->prefix);
					kv_push(ref_list->refs, line_ref);
				}
				line_iter = line_iter->pnext;
			}

			Section* old_s = old_line->parent_section;
			int delta_n = old_s->n;
			int delta_bytes = old_s->total;
			update_count_recursively(old_s, -delta_n, -delta_bytes);
			sectionlist_remove(old_s);

			update_count_recursively(prev_section, delta_n+1, delta_bytes+new_line.len);

			new_line.pnext = next_l;
			new_line.pprev = prev_l;

			// actually pointing to new_line because 
			// new_line content will be copied old_line location
			if(prev_l) {
				prev_l->pnext = old_line;
			}

			if(next_l) {
				next_l->pprev = old_line;
			}


		} else if(new_line.type == REFERENCE) {
			size_t len = fp - line;
			char* prefix = xmalloc(len+1);
			STRNCPY(prefix, line, len);
			prefix[len] = '\0';

			len = (lp+1)-(fp+1);
			char* name = xmalloc(len+1);
			STRNCPY(name, fp+1, len);
			name[len] = '\0';


			new_line.name = name;
			new_line.prefix = prefix;

			Line* next_l = next_line(old_line);
			Line* prev_l = prev_line(old_line, &curbuf->first_line);

			Section* prev_section = prev_l->parent_section;

			new_line.parent_section = prev_section;

			Line* line_iter = next_l;
			while(line_iter->pnext) {
				line_iter->parent_section = prev_section;
				line_iter = line_iter->pnext;
			}


			line_iter = next_l;
			while(line_iter->pnext) {
				if(line_iter->type == REFERENCE) {
					SectionList* ref_list = get_section_list(&curbuf->sections, line_iter->name);
					LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
					remove_ref(ref_list, old_ref);
					LineRef line_ref;
					line_ref.section = prev_section;
					line_ref.id = line_iter->id;
					line_ref.prefix_len = strlen(line_iter->prefix);
					kv_push(ref_list->refs, line_ref);
				}
				line_iter = line_iter->pnext;
			}

			SectionList* list = get_section_list(&curbuf->sections, name);
			LineRef line_ref;
			line_ref.section = prev_section;
			line_ref.id = new_line.id;
			line_ref.prefix_len = strlen(new_line.prefix);
			kv_push(list->refs, line_ref);
			if(list->n < 0) {
				list->n = 0;
			}

			Section* old_s = old_line->parent_section;
			int delta_n = old_s->n;
			int delta_bytes = old_s->total;
			update_count_recursively(old_s, -delta_n, -delta_bytes);
			sectionlist_remove(old_s);

			int ref_n, ref_bytes;
			get_tangle_line_size(&new_line, &ref_n, &ref_bytes);
			update_count_recursively(prev_section, delta_n + ref_n, delta_bytes + ref_bytes);

			new_line.pnext = next_l;
			new_line.pprev = prev_l;

			// actually pointing to new_line because 
			// new_line content will be copied old_line location
			if(prev_l) {
				prev_l->pnext = old_line;
			}

			if(next_l) {
				next_l->pprev = old_line;
			}


		} else if(new_line.type == SECTION) {
			buf_T* buf = curbuf;
			Section* cur_section;
			int op;
			switch(*(fp+1)) {
			case '+': op = 1; break;
			case '-': op = 2; break;
			default: op = 0; break;
			}

			// fp  fp+1 ... lp
			// @    +   
			// len = 0 if fp+1 == lp
			size_t len = lp - (fp+1);
			char* name = xmalloc(len + 1);
			STRNCPY(name, fp+2, len);
			name[len] = '\0';

			if(strcmp(old_line->name, name) != 0) {
				SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);


				Section* section = (Section*)xcalloc(1, sizeof(Section));

				cur_section = section;

				SectionList* list;
				if(op == 1 || op == 2) {
					list = get_section_list(&buf->sections, name);
				  if(op == 1) {
				    sectionlist_push_back(list, section);

				  } else { /* op == 2 */
				    sectionlist_push_front(list, section);

				  }
				}

				else {
				  if(pmap_has(cstr_t)(&buf->sections, name)) {
				    list = pmap_get(cstr_t)(&buf->sections, name);
				  } else {
				    list = sectionlist_init(name);
				    pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
				    pmap_put(cstr_t)(&buf->tgl_bufs, xstrdup(name), NULL);
				  }


				  sectionlist_clear(list);
					list->root = true;

				  sectionlist_push_back(list, section);
				}


				if(list->n == -1 || list->total == -1) {
					list->n = 0;
					list->total = 0;
				}


				new_line.name = name;
				new_line.pnext = NULL;
				new_line.pprev = NULL;
				new_line.parent_section = section;

				Line* next_l = next_line(old_line);
				Line* last_l = old_line->parent_section->tail.pprev;

				Line* next_line = next_l;
				while(next_line && next_line->pnext) {
					next_line->parent_section = section;
					next_line = next_line->pnext;
				}

				next_line = next_l;

				int removed = 0;
				int removed_bytes = 0;

				while(next_line && next_line->pnext) {
					int n, bytes;
					get_tangle_line_size(next_line, &n, &bytes);
					removed += n;
					removed_bytes += bytes;
					next_line = next_line->pnext;
				}

				next_line = next_l;

				Section* old_section = old_line->parent_section;
				while(next_line && next_line->pnext) {
					if(next_line->type == REFERENCE) {
						SectionList* ref_list = get_section_list(&curbuf->sections, next_line->name);
						LineRef old_ref = { .section = old_line->parent_section, .id = old_line->id };
						remove_ref(ref_list, old_ref);
						LineRef line_ref;
						line_ref.section = section;
						line_ref.id = next_line->id;
						line_ref.prefix_len = strlen(next_line->prefix);
						kv_push(ref_list->refs, line_ref);
					}
					next_line = next_line->pnext;
				}

				Section* old_s = old_line->parent_section;
				int delta_n = old_s->n;
				int delta_bytes = old_s->total;
				update_count_recursively(old_s, -delta_n, -delta_bytes);
				sectionlist_remove(old_s);

				update_count_recursively(section, delta_n, delta_bytes);

				section->head.pnext = next_l;
				section->tail.pprev = last_l;


				if(op == 0 && old_list->root) {
					buf_T* dummy_buf = pmap_get(cstr_t)(&curbuf->tgl_bufs, old_line->name);
					assert(dummy_buf);

					aco_save_T aco;
					aucmd_prepbuf(&aco, dummy_buf);
					int ren_ret = rename_buffer(name);
					aucmd_restbuf(&aco);

				}

			}

		}
	}


	*old_line = new_line;

}

void update_count_recursively(Section* section, int delta_n, int delta_total)
{
	section->n += delta_n;
	section->total += delta_total;
	SectionList* list = section->parent;
	list->n += delta_n;
	list->total += delta_total;

	for (size_t i = 0; i < kv_size(list->refs); i++) {
		LineRef line_ref = kv_A(list->refs, i);
		update_count_recursively(line_ref.section, delta_n, delta_n * line_ref.prefix_len + delta_total);
	}
}

static void remove_ref(SectionList* list, LineRef ref)
{
	int i = 0;
	for(; i<kv_size(list->refs); ++i) {
		LineRef cur_ref = kv_A(list->refs, i);
		if(cur_ref.section == ref.section && cur_ref.id == ref.id) {
			break;
		}
	}
	assert(i < kv_size(list->refs));

	for(int j=i; j<kv_size(list->refs)-1; ++j) {
		kv_A(list->refs, i) = kv_A(list->refs, i+1);
	}
	kv_pop(list->refs);
}

static void get_tangle_line_size(Line* line, int* n, int* bytes)
{
	if(line->type == REFERENCE) {
		int ref_n, ref_total;
		tangle_get_count(curbuf, line->name, &ref_n, &ref_total);
		*n = ref_n;
		*bytes = ref_n*strlen(line->prefix) + ref_total;
		return;
	} else if(line->type == TEXT) {
		*n = 1;
		*bytes = line->len;
		return;
	}
	*n = 0;
	*bytes = 0;
	return;
}

void tangle_open_line()
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	Line l;
	l.type = TEXT;
	l.pnext = NULL;
	l.pprev = NULL;
	l.len = 0;

	buf_T* buf = curbuf;
	l.id = ++buf->line_counter;
	Line* pl = tree_insert(curbuf->tgl_tree, lnum-1, &l);

	Line* prev_l = prev_line(pl, &curbuf->first_line);
	Line* next_l = next_line(pl);

	insert_in_section(prev_l->parent_section, prev_l, next_l, pl);

	update_count_recursively(pl->parent_section, 1, l.len);


	int offset = relative_offset_section(prev_l);
	tangle_inserted_lines(offset, 0, 1, prev_l);
}

void insert_in_section(Section* section, Line* prev_l, Line* next_l, Line* pl)
{
	if(prev_l && prev_l->type != SECTION) {
		pl->pprev = prev_l;
		prev_l->pnext = pl;
	} else {
		section->head.pnext = pl;
		pl->pprev = &section->head;
	}

	if(next_l && next_l->type != SECTION) {
		pl->pnext = next_l;
		next_l->pprev = pl; 
	} else {
		section->tail.pprev = pl;
		pl->pnext = &section->tail;
	}

	pl->parent_section = section;
}

void tangle_delete_lines(int count)
{
	size_t col = (size_t)curwin->w_cursor.col;
	linenr_T lnum = curwin->w_cursor.lnum;

	Line* line = tree_lookup(curbuf->tgl_tree, lnum-1);

	Line* prev_l = prev_line(line, &curbuf->first_line);
	Section* prev_section = prev_l->parent_section;
	Section* cur_section = prev_section;
	int deleted_from_prev = 0;
	int deleted_from_prev_bytes = 0;

	kvec_t(Section*) sections_to_delete = KV_INITIAL_VALUE;


	for(int j=0;j < count; ++j) {
		if(line->type == TEXT) {
			if(prev_section == cur_section) {
				int n, bytes;
				get_tangle_line_size(line, &n, &bytes);
				deleted_from_prev += n;
				deleted_from_prev_bytes += bytes;
			}
			remove_line_from_section(line);
		}

		else if(line->type == REFERENCE) {
			if(prev_section == cur_section) {
				int n, bytes;
				get_tangle_line_size(line, &n, &bytes);
				deleted_from_prev += n;
				deleted_from_prev_bytes += bytes;
			}

			Line* old_line = line;
			{
			SectionList* old_list = get_section_list(&curbuf->sections, old_line->name);
			LineRef line_ref = { .section = old_line->parent_section, .id = old_line->id };
			remove_ref(old_list, line_ref);
			}

			remove_line_from_section(line);
		}


		else if(line->type == SECTION) {
			cur_section = line->parent_section;
			kv_push(sections_to_delete, cur_section);

			SectionList* old_list = cur_section->parent;
			if(old_list->root) {
				buf_T* bufdel = pmap_get(cstr_t)(&curbuf->tgl_bufs, line->str);
				assert(bufdel);

				bool force = true;
				bool unload = false;

			  int result = do_buffer(DOBUF_WIPE, DOBUF_FIRST, FORWARD, bufdel->handle, force);
				pmap_del(cstr_t)(&curbuf->tgl_bufs, line->str);
			}


		}


		// This could potentially be faster by avoiding
		// the downward search because we already know 
		// the location in the tree
		line = tree_delete(curbuf->tgl_tree, lnum-1);

	}


	if(prev_section) {
		update_count_recursively(prev_section, -deleted_from_prev, -deleted_from_prev_bytes);
	}
	if(prev_section != cur_section) {
		Line* line_n = line;
		while(line_n && line_n->pnext) {
			if(line_n->type == REFERENCE) {
				SectionList* ref_list = get_section_list(&curbuf->sections, line_n->name);
				LineRef old_ref = { .section = line_n->parent_section, .id = line_n->id };
				LineRef new_ref = { .section = prev_section, .id = line_n->id, .prefix_len = strlen(line_n->prefix) };
				replace_ref(ref_list, old_ref, new_ref);
			}
			line_n = line_n->pnext;
		}
	}

	if(prev_section != cur_section) {
		int added = 0, added_bytes = 0;
		Line* line_n = line;
		while(line_n && line_n->pnext) {
			line_n->parent_section = prev_section;
			int n, bytes;
			get_tangle_line_size(line_n, &n, &bytes);
			added += n;
			added_bytes += bytes;
			line_n = line_n->pnext;
		}

		if(prev_section) {
			update_count_recursively(prev_section, added, added_bytes);
		}
	}

	if(prev_section != cur_section) {
		Line* line_n = line;
		if(line_n) {
			if(prev_l->type == SECTION) {
				line_n->pprev = &prev_section->head;
				prev_section->head.pnext = line_n;
			} else {
				line_n->pprev = prev_l;
				prev_l->pnext = line_n;
			}
		}

		if(line_n) {
			prev_section->tail.pprev = cur_section->tail.pprev;
			cur_section->tail.pprev->pnext = &prev_section->tail;
		}

	}


	for(int i=0; i<kv_size(sections_to_delete); ++i) {
		Section* old_s = kv_A(sections_to_delete, i);

		update_count_recursively(old_s, -old_s->n, -old_s->total);
		sectionlist_remove(old_s);

	}

}

void remove_line_from_section(Line* line)
{
	line->pprev->pnext = line->pnext;
	line->pnext->pprev = line->pprev;
}

static void replace_ref(SectionList* list, LineRef old_ref, LineRef new_ref)
{
	int i = 0;
	for(; i<kv_size(list->refs); ++i) {
		LineRef ref = kv_A(list->refs, i);
		if(ref.section == old_ref.section && ref.id == old_ref.id) {
			break;
		}
	}
	assert(i < kv_size(list->refs));
	kv_A(list->refs, i) = new_ref;
}

int get_buf_line_count_tangle(buf_T* buf)
{
	SectionList* list = pmap_get(cstr_t)(&buf->parent_tgl->sections, buf->b_fname);
	return list->n;
}

void tangle_update(buf_T* buf)
{
	const char* name;
	SectionList* list;
	int n, total;
  map_foreach(&buf->sections, name, list, {
		tangle_get_count(buf, name, &n, &total);
  });
}

void tangle_get_count(buf_T* buf, const char* name, int* n, int* total)
{
	if(!pmap_has(cstr_t)(&buf->sections, name)) {
		*n = 0;
		*total = 0;
		return;
	}

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	if(list->n != -1 && list->total != -1) {
		*n = list->n;
		*total = list->total;
		return;
	}

	list->n = 0;
	list->total = 0;
	Section* section = list->phead;
	while(section) {
		section->n = 0;
		section->total = 0;
		Line* line = section->head.pnext;
		while(line != &section->tail) {
			if(line->type == TEXT) {
				section->n++;
				section->total += line->len;
			} else if(line->type == REFERENCE) {
				int ref_n, ref_total;
				tangle_get_count(buf, line->name, &ref_n, &ref_total);

				int prefix_len = strlen(line->prefix);

				section->n += ref_n;
				section->total += ref_n*prefix_len + ref_total;
			}
			line = line->pnext;
		}

		list->n += section->n;
		list->total += section->total;
		section = section->pnext;
	}


	*n = list->n;
	*total = list->total;
}

void tangle_parse(buf_T *buf)
{
  pmap_clear(cstr_t)(&buf->sections);
  pmap_clear(cstr_t)(&buf->tgl_bufs);

  Section* cur_section = NULL;

  buf->tgl_tree = create_tree();

  for(int i=1; i<=buf->b_ml.ml_line_count; ++i) {
    char* line = ml_get(i);
    char* fp = strnwfirst(line);
    if(fp == NULL) {
      continue;
    }

    if(*fp == '@') {
      if(*(fp+1) != '@') {
        char* lp = strnwlast(line);

        if(*(fp+1) == '=' || *(fp+1) == '+' || *(fp+1) == '-') {
          int op;
          switch(*(fp+1)) {
          case '+': op = 1; break;
          case '-': op = 2; break;
          default: op = 0; break;
          }

          // fp  fp+1 ... lp
          // @    +   
          // len = 0 if fp+1 == lp
          size_t len = lp - (fp+1);
          char* name = xmalloc(len + 1);
          STRNCPY(name, fp+2, len);
          name[len] = '\0';

          Section* section = (Section*)xcalloc(1, sizeof(Section));

          cur_section = section;

          SectionList* list;
          if(op == 1 || op == 2) {
          	list = get_section_list(&buf->sections, name);
            if(op == 1) {
              sectionlist_push_back(list, section);

            } else { /* op == 2 */
              sectionlist_push_front(list, section);

            }
          }

          else {
            if(pmap_has(cstr_t)(&buf->sections, name)) {
              list = pmap_get(cstr_t)(&buf->sections, name);
            } else {
              list = sectionlist_init(name);
              pmap_put(cstr_t)(&buf->sections, xstrdup(name), list);
              pmap_put(cstr_t)(&buf->tgl_bufs, xstrdup(name), NULL);
            }


            sectionlist_clear(list);
          	list->root = true;

            sectionlist_push_back(list, section);
          }


          Line l;
          l.type = SECTION;
          l.name = name;
          l.pnext = NULL;
          l.pprev = NULL;
          l.parent_section = section;

          l.id = ++buf->line_counter;
          Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);


        } else {
          size_t len = fp - line;
          char* prefix = xmalloc(len+1);
          STRNCPY(prefix, line, len);
          prefix[len] = '\0';

          len = (lp+1)-(fp+1);
          char* name = xmalloc(len+1);
          STRNCPY(name, fp+1, len);
          name[len] = '\0';

          Line l;
          l.type = REFERENCE;
          l.name = name;
          l.prefix = prefix;
          l.pnext = NULL;
          l.pprev = NULL;

          l.id = ++buf->line_counter;
          Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);

          add_to_section(cur_section, pl);

          SectionList* list = get_section_list(&buf->sections, name);
          LineRef line_ref;
          line_ref.section = cur_section;
          line_ref.id = l.id;
          line_ref.prefix_len = strlen(prefix);
          kv_push(list->refs, line_ref);


        }
      } else {
    		Line l;
    		l.type = TEXT;
    		l.pnext = NULL;
    		l.pprev = NULL;
    		l.len = strlen(line)+1;

    		l.id = ++buf->line_counter;
    		Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);

    		add_to_section(cur_section, pl);

      }
    }

    else {
    	Line l;
    	l.type = TEXT;
    	l.pnext = NULL;
    	l.pprev = NULL;
    	l.len = strlen(line)+1;

    	l.id = ++buf->line_counter;
    	Line* pl = tree_insert(buf->tgl_tree, buf->tgl_tree->total, &l);

    	add_to_section(cur_section, pl);

    }

  }
  SectionList* top_list = get_section_list(&curbuf->sections, "__top__");
  Section* top_section = (Section*)xcalloc(1, sizeof(Section));
  top_section->head.pnext = &top_section->tail;
  top_section->tail.pprev = &top_section->head;
  sectionlist_push_back(top_list, top_section);

  buf->first_line.type = SECTION;
  buf->first_line.parent = NULL;
  buf->first_line.parent_section = top_section;

}

SectionList* get_section_list(PMap(cstr_t)* sections, const char* name)
{
	SectionList* list;
	if(!pmap_has(cstr_t)(sections, name)) {
    list = sectionlist_init(name);
    pmap_put(cstr_t)(sections, xstrdup(name), list);
  } else {
    list = pmap_get(cstr_t)(sections, name);
  }
	return list;
}

static inline void add_to_section(Section* section, Line* pl)
	FUNC_ATTR_ALWAYS_INLINE
{
	if(!section->tail.pprev) {
		section->head.pnext = pl;
		section->tail.pprev = pl;
		pl->pnext = &section->tail;
		pl->pprev = &section->head;
	} else {
		section->tail.pprev->pnext = pl;
		pl->pprev = section->tail.pprev;
		pl->pnext = &section->tail;
		section->tail.pprev = pl;
	}
	pl->parent_section = section;
}

int find_first_parent(Line* line, int lnum, SectionList** root_section_list)
{
	Section* section = line->parent_section;
	SectionList* section_list = section->parent;
	section = section->pprev;
	while(section) {
		lnum += section->n;
		section = section->pprev;
	}

	if(section_list->root) {
		*root_section_list = section_list;
		return lnum;
	}

	else {
		if(kv_size(section_list->refs) > 0) {
			LineRef line_ref = kv_A(section_list->refs, 0);
			Line* parent_line;
			int offset = get_line_from_ref(line_ref, &parent_line);
			return lnum + find_first_parent(parent_line, offset, root_section_list);
		} else {
			return -1;
		}
	}

}

void get_tangle_buf_line(buf_T* parent_buf, Line* line, int* lnum, buf_T** tangle_buf)
{
	SectionList* list;
	int offset = relative_offset_section(line);
	*lnum = find_first_parent(line, offset, &list);
	buf_T* buf = pmap_get(cstr_t)(&parent_buf->tgl_bufs, list->name);
	*tangle_buf = buf;
}

