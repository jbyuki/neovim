local M = {}

local ntangle_compact = nil

function M.get_ntangle()
  if ntangle_compact == nil then
    local found, ntangle  = pcall(require, "ntangle-compact")
    if not found then
      ntangle_compact = found
    else
      ntangle_compact = ntangle
    end
  end
  return ntangle_compact
end

function M.get_tangleBuf_from_attached(source)
  if M.get_ntangle() then
    local activated = M.get_ntangle().activated
    for _, tanglebuf in pairs(activated) do
      for _, tbuf in pairs(tanglebuf.tangle_buf) do
        if tbuf == source then
          return tanglebuf
        end
      end
    end
  end
end

function M.get_tangleBuf(buf)
  if M.get_ntangle() then
    local activated = M.get_ntangle().activated
    return activated[buf]
  end
end

return M

