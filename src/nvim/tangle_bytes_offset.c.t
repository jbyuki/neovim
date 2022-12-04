##tangle
@define_functions+=
// Reimplement "ml_find_line_or_offset" but for tangled buffers
long tangle_find_line_or_offset(buf_T *buf, linenr_T lnum, long *offp, bool no_ff)
{
	if(lnum > 0) {
		@find_byte_offset_of_lnum
	} else {
		@find_line_with_offset_offp
	}
}

@define_functions+=
int get_bytes_at_lnum_tangled(buf_T* buf, const char* name, int lnum, int prefix_len)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	int bytes = 0;
	while(section) {
		if(lnum < section->n) {
			@look_for_lnum_in_section_and_return_byte
		}
		lnum -= section->n;
		lnum -= section->n*prefix_len + section->total;
		section = section->pnext;
	}
	return bytes;
}

@look_for_lnum_in_section_and_return_byte+=
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

@find_byte_offset_of_lnum+=
return get_bytes_at_lnum_tangled(buf->parent_tgl, buf->b_fname, lnum-1, 0);

@define_functions+=
int get_lnum_at_bytes_tangled(buf_T* buf, const char* name, int bytes, int prefix_len)
{
	assert(pmap_has(cstr_t)(&buf->sections, name));

	SectionList* list = pmap_get(cstr_t)(&buf->sections, name);
	Section* section = list->phead;
	int lnum = 0;
	while(section) {
		int section_bytes = section->n*prefix_len + section->total;
		if(bytes < section_bytes) {
			@look_for_bytes_in_section_and_return_byte
		}
		lnum += section->n;
		bytes -= section_bytes;
		section = section->pnext;
	}
	return bytes;
}

@look_for_bytes_in_section_and_return_byte+=
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

@find_line_with_offset_offp+=
return get_lnum_at_bytes_tangled(buf->parent_tgl, buf->b_fname, *offp, 0);
