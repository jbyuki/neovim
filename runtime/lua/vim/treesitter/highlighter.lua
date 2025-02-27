local api = vim.api
local query = vim.treesitter.query
local Range = require('vim.treesitter._range')
local Tangle = require('vim.tangle')
local ntangle = Tangle.get_ntangle()

local ns = api.nvim_create_namespace('treesitter/highlighter')

local enable_perf_analysis = false
local on_line_history = {}
local on_prepare_history = {}

---@alias vim.treesitter.highlighter.Iter fun(end_line: integer|nil): integer, TSNode, vim.treesitter.query.TSMetadata, TSQueryMatch

---@class (private) vim.treesitter.highlighter.Query
---@field private _query vim.treesitter.Query?
---@field private lang string
---@field private hl_cache table<integer,integer>
local TSHighlighterQuery = {}
TSHighlighterQuery.__index = TSHighlighterQuery

---@private
---@param lang string
---@param query_string string?
---@return vim.treesitter.highlighter.Query
function TSHighlighterQuery.new(lang, query_string)
  local self = setmetatable({}, TSHighlighterQuery)
  self.lang = lang
  self.hl_cache = {}

  if query_string then
    self._query = query.parse(lang, query_string)
  else
    self._query = query.get(lang, 'highlights')
  end

  return self
end

---@package
---@param capture integer
---@return integer?
function TSHighlighterQuery:get_hl_from_capture(capture)
  if not self.hl_cache[capture] then
    local name = self._query.captures[capture]
    local id = 0
    if not vim.startswith(name, '_') then
      id = api.nvim_get_hl_id_by_name('@' .. name .. '.' .. self.lang)
    end
    self.hl_cache[capture] = id
  end

  return self.hl_cache[capture]
end

---@nodoc
function TSHighlighterQuery:query()
  return self._query
end

---@class (private) vim.treesitter.highlighter.State
---@field tstree TSTree
---@field next_row integer
---@field iter vim.treesitter.highlighter.Iter?
---@field highlighter_query vim.treesitter.highlighter.Query

---@nodoc
---@class vim.treesitter.highlighter
---@field active table<integer,vim.treesitter.highlighter>
---@field bufnr integer
---@field private orig_spelloptions string
--- A map of highlight states.
--- This state is kept during rendering across each line update.
---@field private _highlight_states vim.treesitter.highlighter.State[]
---@field private _queries table<string,vim.treesitter.highlighter.Query>
---@field tree vim.treesitter.LanguageTree
---@field private redraw_count integer
local TSHighlighter = {
  active = {},
}

TSHighlighter.__index = TSHighlighter

---@nodoc
---
--- Creates a highlighter for `tree`.
---
---@param tree vim.treesitter.LanguageTree parser object to use for highlighting
---@param opts (table|nil) Configuration of the highlighter:
---           - queries table overwrite queries used by the highlighter
---@return vim.treesitter.highlighter Created highlighter object
function TSHighlighter.new(source, trees, opts)
  local self = setmetatable({}, TSHighlighter)

  opts = opts or {} ---@type { queries: table<string,string> }
  self.trees = trees

  for _, tree in pairs(trees) do
    tree:register_cbs({
      on_detach = function()
        local ll = Tangle.get_ll_from_buf(self.bufnr)
        if not ll then
          self:on_detach()
        end
      end,
    })

    tree:register_cbs({
      on_changedtree = function(...)
        self:on_changedtree(...)
      end,
      on_child_removed = function(child)
        child:for_each_tree(function(t)
          self:on_changedtree(t:included_ranges(true))
        end)
      end,
    }, true)
  end

  self.bufnr = source
  self.redraw_count = 0
  self._highlight_states = {}
  self._queries = {}

  -- Queries for a specific language can be overridden by a custom
  -- string query... if one is not provided it will be looked up by file.
  if opts.queries then
    for lang, query_string in pairs(opts.queries) do
      self._queries[lang] = TSHighlighterQuery.new(lang, query_string)
    end
  end

  self.orig_spelloptions = vim.bo[self.bufnr].spelloptions

  vim.bo[self.bufnr].syntax = ''
  vim.b[self.bufnr].ts_highlight = true

  TSHighlighter.active[self.bufnr] = self

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  -- Still need to ensure that syntaxset augroup exists, so that calling :destroy()
  -- immediately afterwards will not error.
  if vim.g.syntax_on ~= 1 then
    vim.cmd.runtime({ 'syntax/synload.vim', bang = true })
    vim.api.nvim_create_augroup('syntaxset', { clear = false })
  end

  vim._with({ buf = self.bufnr }, function()
    vim.opt_local.spelloptions:append('noplainbuffer')
  end)


  for _, tree in pairs(self.trees) do
    tree:parse()
  end

  return self
end

--- @nodoc
--- Removes all internal references to the highlighter
function TSHighlighter:destroy()
  TSHighlighter.active[self.bufnr] = nil

  if api.nvim_buf_is_loaded(self.bufnr) then
    vim.bo[self.bufnr].spelloptions = self.orig_spelloptions
    vim.b[self.bufnr].ts_highlight = nil
    if vim.g.syntax_on == 1 then
      api.nvim_exec_autocmds('FileType', { group = 'syntaxset', buffer = self.bufnr })
    end
  end
end

---@param srow integer
---@param erow integer exclusive
---@private
function TSHighlighter:prepare_highlight_states(srow, erow)
  self._highlight_states = {}

  local start = vim.uv.hrtime()

  for ntbuf, ltree in pairs(self.trees) do
    ltree:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end

      local root_node = tstree:root()
      local root_start_row, _, root_end_row, _ = root_node:range()

      -- Only consider trees within the visible range
      local root_section = Tangle.get_root_section_from_buf(ntbuf)
      if not root_section then
        if root_start_row > erow or root_end_row < srow then
          return
        end
      end

      local highlighter_query = self:get_query(tree:lang())

      -- Some injected languages may not have highlight queries.
      if not highlighter_query:query() then
        return
      end

      -- _highlight_states should be a list so that the highlights are added in the same order as
      -- for_each_tree traversal. This ensures that parents' highlight don't override children's.
      table.insert(self._highlight_states, {
        tstree = tstree,
        next_row = 0,
        iter = nil,
        root_section = root_section,
        highlighter_query = highlighter_query,
      })
    end)
  end

  local stop = vim.uv.hrtime()
  if enable_perf_analysis then
    table.insert(on_prepare_history , (stop - start)/1e6)
  end
end

---@param fn fun(state: vim.treesitter.highlighter.State)
---@package
function TSHighlighter:for_each_highlight_state(fn)
  for _, state in ipairs(self._highlight_states) do
    fn(state)
  end
end

---@package
function TSHighlighter:on_detach()
  self:destroy()
end

---@package
---@param changes Range6[]
function TSHighlighter:on_changedtree(changes)
  for _, ch in ipairs(changes) do
    api.nvim__redraw({ buf = self.bufnr, range = { ch[1], ch[4] + 1 }, flush = false })
  end
end

--- Gets the query used for @param lang
---@nodoc
---@param lang string Language used by the highlighter.
---@return vim.treesitter.highlighter.Query
function TSHighlighter:get_query(lang)
  if not self._queries[lang] then
    self._queries[lang] = TSHighlighterQuery.new(lang)
  end

  return self._queries[lang]
end

--- @param match TSQueryMatch
--- @param bufnr integer
--- @param capture integer
--- @param metadata vim.treesitter.query.TSMetadata
--- @return string?
local function get_url(match, bufnr, capture, metadata)
  ---@type string|number|nil
  local url = metadata[capture] and metadata[capture].url

  if not url or type(url) == 'string' then
    return url
  end

  local captures = match:captures()

  if not captures[url] then
    return
  end

  -- Assume there is only one matching node. If there is more than one, take the URL
  -- from the first.
  local other_node = captures[url][1]

  return vim.treesitter.get_node_text(other_node, bufnr, {
    metadata = metadata[url],
  })
end

--- @param capture_name string
--- @return boolean?, integer
local function get_spell(capture_name)
  if capture_name == 'spell' then
    return true, 0
  elseif capture_name == 'nospell' then
    -- Give nospell a higher priority so it always overrides spell captures.
    return false, 1
  end
  return nil, 0
end

---@param self vim.treesitter.highlighter
---@param buf integer
---@param line integer
---@param is_spell_nav boolean
local function on_line_impl(self, buf, line, is_spell_nav)
  if vim.tbl_count(self.trees) == 0 then
    return
  end

  local start = vim.uv.hrtime()

  local bufnr = buf
  local col_off
  local root_section
  local line_type
  local HL

  local ll = Tangle.get_ll_from_buf(bufnr)
  if ll then
    HL = Tangle.get_hl_from_ll(ll)
    local nt_infos = ntangle.TtoNT(bufnr, line)
    for _, nt_info in ipairs(nt_infos) do
      root_section = nt_info[2]
      line = nt_info[3]
      col_off = #nt_info[4]
      bufnr = Tangle.get_mirror_buf_from_root_section(root_section)
      break
    end

    if #nt_infos == 0 then
      line_type = ntangle.get_line_type(bufnr, line)
      if not line_type then
        return
      end
    end
  end

  self:for_each_highlight_state(function(state)
    if line_type then
      local hl = Tangle.hl_group[line_type]
      api.nvim_buf_set_extmark(buf, ns, line, 0, {
        end_line = line+1,
        end_col = 0,
        hl_group = hl,
        ephemeral = true,
      })
      return
    end

    if state.root_section and state.root_section ~= root_section then
      return
    end

    local root_node = state.tstree:root()
    local root_start_row, _, root_end_row, _ = root_node:range()

    -- Only consider trees that contain this line
    if root_start_row > line or root_end_row < line then
      return
    end

    state.iter =
        state.highlighter_query:query():iter_captures(root_node, bufnr, line, root_end_row + 1)

    if HL then
      state.next_row = line
    end

    while line >= state.next_row do
      local capture, node, metadata, match = state.iter(line)

      local range = { root_end_row + 1, 0, root_end_row + 1, 0 }
      if node then
        range = vim.treesitter.get_range(node, bufnr, metadata and metadata[capture])
      end
      local start_row, start_col, end_row, end_col = Range.unpack4(range)

      if capture then
        local hl = state.highlighter_query:get_hl_from_capture(capture)

        local capture_name = state.highlighter_query:query().captures[capture]

        local spell, spell_pri_offset = get_spell(capture_name)

        -- The "priority" attribute can be set at the pattern level or on a particular capture
        local priority = (
          tonumber(metadata.priority or metadata[capture] and metadata[capture].priority)
          or vim.hl.priorities.treesitter
        ) + spell_pri_offset

        local conceal = metadata.conceal or metadata[capture] and metadata[capture].conceal
        local url = get_url(match, bufnr, capture, metadata)

        -- The "conceal" attribute can be set at the pattern level or on a particular capture

        if HL then
          if hl and end_row >= line and (not is_spell_nav or spell ~= nil) then
            local _, sr,_ = ntangle.NTtoT(HL, root_section, start_row)
            local _, er,_ = ntangle.NTtoT(HL, root_section, end_row)

            -- FIX MULTI LINE

            if sr and er then
              if start_row == line then -- FIX THIS
                api.nvim_buf_set_extmark(buf, ns, sr, start_col - col_off, {
                  end_line = er,
                  end_col = end_col - col_off,
                  hl_group = hl,
                  ephemeral = true,
                  priority = priority,
                  conceal = conceal,
                  spell = spell,
                  url = url,
                })
              end
            end
          end

          if start_row > line then
            -- FIX THIS
            state.next_row = start_row
          end
        else
          if hl and end_row >= line and (not is_spell_nav or spell ~= nil) then
            api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
                  end_line = end_row,
                  end_col = end_col,
                  hl_group = hl,
                  ephemeral = true,
                  priority = priority,
                  conceal = conceal,
                  spell = spell,
                  url = url,
                })
          end

          if start_row > line then
            state.next_row = start_row
          end
        end
      end

      if start_row > line then
        state.next_row = start_row
      end
    end
  end)

  local stop = vim.uv.hrtime()
  if enable_perf_analysis then
    table.insert(on_line_history,(stop - start)/1e6)
  end
end

---@private
---@param _win integer
---@param buf integer
---@param line integer
function TSHighlighter._on_line(_, _win, buf, line, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  on_line_impl(self, buf, line, false)
end

---@private
---@param buf integer
---@param srow integer
---@param erow integer
function TSHighlighter._on_spell_nav(_, _, buf, srow, _, erow, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  -- Do not affect potentially populated highlight state. Here we just want a temporary
  -- empty state so the C code can detect whether the region should be spell checked.
  local highlight_states = self._highlight_states
  self:prepare_highlight_states(srow, erow)

  for row = srow, erow do
    on_line_impl(self, buf, row, true)
  end
  self._highlight_states = highlight_states
end

---@private
---@param _win integer
---@param buf integer
---@param topline integer
---@param botline integer
function TSHighlighter._on_win(_, _win, buf, topline, botline)
  local self = TSHighlighter.active[buf]
  if not self then
    return false
  end

  local ll = Tangle.get_ll_from_buf(buf)
  if ll then
    for lnum=topline,botline do
      local nt_infos = ntangle.TtoNT(buf, lnum)
      for _, nt_info in ipairs(nt_infos) do
        local ntbuf = ntangle.root_to_mirror_buf[nt_info[2]]
        if ntbuf then
          if not self.trees[ntbuf] then
            self.trees[ntbuf] = vim.treesitter.get_parser(ntbuf)
          end

          if self.trees[ntbuf] then
            local line = nt_info[3]
            self.trees[ntbuf]:parse({line, line+1})
          end
        end
      end
    end
  else
    self.trees[buf]:parse({ topline, botline + 1 })
  end

  self:prepare_highlight_states(topline, botline + 1)
  self.redraw_count = self.redraw_count + 1
  return true
end

api.nvim_set_decoration_provider(ns, {
  on_win = TSHighlighter._on_win,
  on_line = TSHighlighter._on_line,
  _on_spell_nav = TSHighlighter._on_spell_nav,
})

function TSHighlighter.start_analysis()
  enable_perf_analysis = true
  on_line_history = {}
  on_prepare_history = {}
end

function TSHighlighter.stop_analysis()
  enable_perf_analysis = false
  return on_line_history, on_prepare_history 
end

return TSHighlighter
