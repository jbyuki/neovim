local lines = {}
for line in io.lines("test.cpp") do
  table.insert(lines, line)
end

local test = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(test, 0, -1, true, lines)
vim.bo[test].filetype = "cpp"

local bufnr = 2
vim.api.nvim_buf_attach(test, 0, {
  on_extmark = function(_, buf, ns, start_row, start_col, end_col, end_row, hl, priority, conceal, spell)
    vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col, {
      end_line = end_row,
      end_col = end_col,
      hl_group = hl,
      ephemeral = true,
      conceal = conceal,
      priority = priority, -- Low but leaves room below
      spell = spell
    })
    return true
  end
})

vim.treesitter.highlighter._on_buf_line[bufnr] = function(_, line)
  return test, line
end

