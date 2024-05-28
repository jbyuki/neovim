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
      for _, ntbuf in pairs(tanglebuf.ntbuf) do
        if ntbuf == source then
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

function M.get_rootElem(tanglebuf, buf)
  if tanglebuf then
    for head, ntbuf in pairs(tanglebuf.ntbuf) do
      if ntbuf == buf then
        return head
      end
    end
  end
end

return M

