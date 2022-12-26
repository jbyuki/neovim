--- General options {{{
vim.o.nu = true
vim.o.rnu = true
vim.o.ai = true
vim.o.si = true
vim.o.incsearch = true
vim.o.hlsearch = true
vim.o.showmode = false

vim.o.ts = 2
vim.o.sw = 2
vim.o.sts = 2
vim.o.expandtab = false
vim.o.hidden = true
vim.o.autoread = true
vim.o.clipboard = "unnamedplus"

vim.o.packpath = vim.o.packpath .. ",C:\\Users\\jybur\\fakeroot\\code\\nvimplugins"
vim.o.mouse = ""
vim.g.markdown_recommended_style = 0
-- vim.o.rtp = "C:\\Users\\jybur\\fakeroot\\code\\experiments\\neovim\\runtime,$VIMRUNTIME"
vim.o.rtp = "C:\\Users\\jybur\\fakeroot\\code\\experiments\\neovim\\runtime"

--- }}}
--- General keymaps {{{

vim.api.nvim_set_keymap('n', 'K', [[:execute ":help " . expand('<cword>')<CR>]], {})

vim.api.nvim_set_keymap('i', 'jk', '<ESC>', {})
vim.api.nvim_set_keymap('t', 'jk', [[<C-\><C-n>]], {})
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR><CR>', { noremap = true, silent = true })
vim.g.mapleader = ' '

vim.api.nvim_set_keymap('n', '<leader>p', ':cd %:p:h<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>d', ':!del /Q C:\\Users\\jybur\\AppData\\Local\\nvim-data\\swap\\*<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>t', ':tabnew<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<A-j>', ':m .+1<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<A-k>', ':m .-2<CR>', { noremap = true, silent = true })
vim.cmd [[vnoremap <A-j> :m '>+1<CR>gv=gv]]
vim.cmd [[vnoremap <A-k> :m '<-2<CR>gv=gv]]

vim.api.nvim_set_keymap('n', '<leader>j', '<c-]>', {})
vim.api.nvim_set_keymap('n', '<C-z>', '<Nop>', {})
vim.api.nvim_set_keymap('n', '<leader>o', [[:execute "!start " . glob("build/*.sln")<CR>]], {})
vim.api.nvim_set_keymap('n', '<leader>z', [[:cd ..<CR>]], {})
--- }}}
-- macros {{{
local keymap = function(key, fn)
  vim.api.nvim_set_keymap("n", key, "", { noremap = true, callback = function()  
    fn()
  end})
end

local vkeymap = function(key, fn)
  vim.api.nvim_set_keymap("v", key, "<CR>", { noremap = true, callback = fn })
end
-- }}}

-- Remove automatic commenting {{{
vim.api.nvim_create_autocmd({"FileType"}, { callback = function() 
  local bufnr = vim.api.nvim_get_current_buf()
  local fmt = vim.bo[bufnr].formatoptions
  fmt = fmt:gsub("c", "")
  fmt = fmt:gsub("r", "")
  fmt = fmt:gsub("o", "")
  vim.bo[bufnr].formatoptions = fmt
end})

-- }}}
-- python {{{
vim.g.python3_host_prog = "C:/Users/jybur/miniconda3/python.exe"

vim.api.nvim_create_autocmd({"BufEnter"}, { 
	pattern = {"*.py"},
	callback = function() 
		local bufnr = vim.api.nvim_get_current_buf()
		vim.bo[bufnr].ts = 2
		vim.bo[bufnr].sw = 2
		vim.bo[bufnr].sts = 2
	end})

-- }}}
-- wiki {{{
vim.api.nvim_set_keymap("n", "<leader>ww", ":e C:/Users/jybur/fakeroot/doc/wiki/index.txt<CR>", {})
-- }}}

-- Colorscheme {{{
local overrides = {
	StatusLine = { bg = "None" },
	StatusLineNC = { bg = "None" },
	TabLine = { bg = "None" },
	TabLineFill = { bg = "None" },
}

require"kanagawa".setup {
	transparent = true,
	overrides = overrides,
}
vim.cmd("colorscheme kanagawa")

-- vim.cmd [[hi Normal guibg=None]]

-- vim.cmd [[hi StatusLine guibg=None]]
-- vim.cmd [[hi StatusLineNC guibg=None]]

-- vim.cmd [[hi TabLine guibg=None]]
-- vim.cmd [[hi TabLineFill guibg=None]]
-- }}}

-- filexplorer.nvim {{{
vim.api.nvim_set_keymap('n', '<leader>l', '', { callback = function()
  require "fileexplorer".list_files(vim.fn.getcwd())
end })
--- }}}
-- oldfiles.nvim {{{
vim.api.nvim_set_keymap('n', '<leader>k', '', { callback = function()
  require "oldfiles".open_old_files()
end })

require"oldfiles".read_oldfiles()

vim.api.nvim_create_autocmd({"BufRead"}, {
  callback = function() require"oldfiles".add_to_oldfiles() end,
})

vim.api.nvim_create_autocmd({"VimLeavePre"}, {
  callback = function() require"oldfiles".write_oldfiles() end,
})
--- }}}
-- ntangle.nvim {{{
vim.api.nvim_set_keymap("n", "<leader>i", "", { callback = function()  
  require"ntangle".transpose()
end})

vim.api.nvim_set_keymap("n", "<leader>u", "", { callback = function()  
  require"ntangle".show_assemble()
end})

vim.api.nvim_set_keymap("n", "<leader>fz", "", { callback = function()  
  require"ntangle".jump_cache("~/ntangle_cache.txt")
end})

vim.api.nvim_set_keymap("n", "<leader>fu", "", { callback = function()  
  require"ntangle".show_helper()
end})

vim.api.nvim_set_keymap("n", "<leader>n", "yyGo<ESC>pV10<$a+=<ESC>o", { silent = true })
-- }}}
-- nvim-treesitter.nvim {{{
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
  playground = {
    enable = true,
    disable = {},
    updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
    persist_queries = false, -- Whether the query persists across vim sessions
    keybindings = {
      toggle_query_editor = 'o',
      toggle_hl_groups = 'i',
      toggle_injected_languages = 't',
      toggle_anonymous_nodes = 'a',
      toggle_language_display = 'I',
      focus_language = 'f',
      unfocus_language = 'F',
      update = 'R',
      goto_node = '<cr>',
      show_help = '?',
    },
  },
}
--}}}
-- carrot.nvim {{{
vim.api.nvim_set_keymap("n", "<F3>", ":CarrotEval<CR>", { silent = true })
vim.api.nvim_set_keymap("n", "<F4>", ":CarrotNewBlock<CR>", { silent = true })
-- }}}
-- reload.nvim {{{
vim.api.nvim_set_keymap("n", "<leader>fr", "", { callback = function()  
  require"reload".open()
end})

-- }}}
-- osv {{{
local dap = require"dap"
dap.configurations.lua = { 
  { 
    type = 'nlua', 
    request = 'attach',
    name = "Attach to running Neovim instance",
  }
}

dap.adapters.nlua = function(callback, config)
  callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
end

vim.api.nvim_set_keymap('n', '<F8>', [[:lua require"dap".toggle_breakpoint()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F9>', [[:lua require"dap".continue()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F10>', [[:lua require"dap".step_over()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<S-F10>', [[:lua require"dap".step_into()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F12>', [[:lua require"dap.ui.widgets".hover()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F5>', [[:lua require"osv".launch({port = 8086})<CR>]], { noremap = true })
-- }}}
-- dash {{{
vim.api.nvim_set_keymap("n", "<leader>h", ":DashRun<CR>", {})
-- }}}
-- monolithic.nvim {{{
vim.api.nvim_set_keymap("n", "<leader>s", "", { callback = function()  
  require"monolithic".open()
end})
require"monolithic".setup {
  exclude_dirs = { ".git" },
  max_files = 3000,
  highlight = false,
}
-- }}}
-- nabla.nvim {{{
keymap("<leader>g", function() require"nabla".toggle_virt() end)
-- }}}
-- ntangle-notebook.nvim {{{
keymap("<leader>r", function() require"ntangle-notebook".send_ntangle() end)
keymap("<leader>q", function() require"ntangle-notebook".inspect_ntangle() end)
vim.cmd [[vnoremap <silent> <leader>r :lua require"ntangle-notebook".send_ntangle_visual()<CR>]]
vim.cmd [[command! QtConsole :!start /b C:\\Users\\jybur\\miniconda3\\python.exe -m qtconsole --JupyterWidget.include_other_output=True --style monokai]]
vim.cmd [[command! QtConsole37 :!start /b C:\\Users\\jybur\\miniconda3\\envs\\py37\\python.exe -m qtconsole --JupyterWidget.include_other_output=True --style monokai]]
vim.g.ntangle_notebook_runtime_dir = "C:/Users/jybur/AppData/Roaming/jupyter/runtime"
-- }}}
-- pack-update.nvim {{{
vim.g.github_pack_path = "C:/Users/jybur/fakeroot/code/nvimplugins/pack/github/start"
vim.cmd [[command! Packupdate :lua require"pack-update".update_all()<CR>]]
-- }}}
-- wiki.nvim {{{
keymap("<F2>", function() require"wiki".create_page() end)
-- }}}
-- venn.nvim {{{
vim.cmd [[vnoremap <leader>g :VBox<CR>]]
-- }}}
-- vim-easy-align {{{
vim.cmd [[xmap ga <Plug>(EasyAlign)]]
-- }}}
-- gitsigns.nvim {{{
require('gitsigns').setup{
  signcolumn = false
}
-- }}}
-- leap.nvim {{{
require('leap').add_default_mappings()
-- }}}
-- zenmode.nvim {{{
require("zen-mode").setup {
	window = {
		backdrop = 1,
		width = .55,
		options = {
			number = false,
			relativenumber = false,
		}
	},
	plugins = {
		options = {
			enabled = true,
			ruler = false, -- disables the ruler text in the cmd line area
			showcmd = false, -- disables the command in the last line of the screen
		},
	}
}
-- }}}
-- luasnip {{{
vim.keymap.set('i', '<Tab>', function()
	if require"luasnip".expand_or_jumpable() then
		return '<Plug>luasnip-expand-or-jump'
	else
		return '<Tab>'
	end
end, { silent = true, expr = true, remap = true })
vim.keymap.set('i', '<S-Tab>', function() require"luasnip".jump(-1) end)

vim.keymap.set('s', '<Tab>', function() require"luasnip".jump(1) end)
vim.keymap.set('s', '<S-Tab>', function() require"luasnip".jump(-11) end)

require"luasnip-snippets.tex"

-- }}}

-- advent of code {{{
vim.g.aoc_session = "53616c7465645f5f364a3599b4b27dc71d8204af76e9b036ecab7144dda57a50b4a8e3e1b3c3548ee14257bbcaec8272d1cffe74360ac76f5fc9839999a7935e" 
--}}}

-- User defined commands {{{
vim.api.nvim_create_user_command("PickRandom", function()
	local count = vim.api.nvim_buf_line_count(0)
	local row = math.random(count)
	vim.api.nvim_win_set_cursor(0, { row, 0 })
end, { force = true })

vim.api.nvim_create_user_command("T", function()
  require"tangle-debug".define_autocmd()
  vim.cmd [[set tangle]]
  require"tangle-debug".enable_virt()
	local bufs = vim.api.nvim_tangle_get_bufs(0)
  require"tangle-debug".capture_dummy_bufs(bufs[1])
end, { force = true })

print("special init.lua loaded.")
-- vim:foldmethod=marker:
