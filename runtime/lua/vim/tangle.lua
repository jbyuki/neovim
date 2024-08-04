local M = {}

local ntangle_inc = nil

function M.get_ntangle()
  if ntangle_inc == nil then
    local found, ntangle  = pcall(require, "ntangle-inc")
    if not found then
      ntangle_inc = found
    else
      ntangle_inc = ntangle
      if not M.hl_group then
        M.init_hl()
      end
    end
  end
  return ntangle_inc
end

function M.init_hl()
  M.hl_group = {
    [ntangle_inc.HL_ELEM_TYPE.TEXT] = "NTangleText",
    [ntangle_inc.HL_ELEM_TYPE.SECTION_PART] = "NTangleSectionPart",
    [ntangle_inc.HL_ELEM_TYPE.REFERENCE] = "NTangleReference",
    [ntangle_inc.HL_ELEM_TYPE.META_SECTION] = "NTangleMetaSection",
    [ntangle_inc.HL_ELEM_TYPE.FILLER] = "NTangleFiller",
  }
end


function M.get_ll_from_buf(source)
  if M.get_ntangle() then
    source = source == 0 and vim.api.nvim_get_current_buf() or source

    local ntangle = M.get_ntangle()
    local ll = ntangle.lls[source]
    return ll
  end
end

function M.get_buf_from_ll(ll)
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    for buf,_ll in pairs(ntangle.lls) do
      if _ll == ll then
        return buf
      end
    end
  end
end

function M.get_hl_from_ll(ll)
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    if ll then
      return ntangle.ll_to_hl[ll]
    end
  end
end

function M.get_lls_from_hl(hl)
  local lls = {}
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()

    for _ll,_hl in pairs(ntangle.ll_to_hl) do
      if hl == _hl then
        table.insert(lls, _ll)
      end
    end
  end
  return lls
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

function M.get_mirror_buf_from_root_section(root_section)
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    return ntangle.root_to_mirror_buf[root_section]
  end
end

function M.get_hl_from_buf(buf)
  if M.get_ntangle() then
    local ntangle = M.get_ntangle()
    return ntangle.buf_to_hl[buf]
  end
end

return M

