local M = {}

local ntangle_inc = nil

function M.get_ntangle()
  if ntangle_inc == nil then
    local found, ntangle  = pcall(require, "ntangle-inc")
    if not found then
      ntangle_inc = found
    else
      ntangle_inc = ntangle
    end
  end
  return ntangle_inc
end

function M.get_hl_from_attached(source)
  if M.get_ntangle() then
    source = source == 0 and vim.api.nvim_get_current_buf() or source

    local ntangle = M.get_ntangle()
    local ll = ntangle.lls[source]
    if ll then
      return ntangle.ll_to_hl[ll]
    end
  end
end

function M.get_bufs_from_hl(hl)
  local bufs = {}
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    for buf,hli in pairs(ntangle.buf_to_hl) do
      if hl == hli then
        table.insert(bufs, buf)
      end
    end
  end
  return bufs
end

function M.get_root_section_from_buf(buf)
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    return ntangle.mirror_buf_to_root[buf]
  end
end

return M

