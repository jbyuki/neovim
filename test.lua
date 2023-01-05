vim.api.nvim_buf_attach(1, true, { 
on_bytes = function(_, buf, _, start_row, start_col, start_byte, old_end_row, old_end_col, old_end_byte, new_end_row, new_end_col, new_end_byte)
	-- local line = vim.api.nvim_buf_get_lines(buf, start_row, start_row+1, true)[1]
	local num_count = vim.api.nvim_buf_line_count(buf)
	local repl = vim.api.nvim_buf_get_text(buf, 0, 0, num_count-1, 0, {})
	print( --line, 
		vim.inspect({start_row, old_end_row, new_end_row}),
		vim.inspect({start_col, old_end_col, new_end_col}), 
		vim.inspect({start_byte, old_end_byte, new_end_byte}), 
		vim.inspect(repl))
end
})
