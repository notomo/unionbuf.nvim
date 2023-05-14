local vim = vim

local M = {}

M.ns = vim.api.nvim_create_namespace("unionbuf")
M.deletion_detector_ns = vim.api.nvim_create_namespace("unionbuf_deletion_detector")

local Entry = {}
Entry.__index = Entry

function M.new(raw_entries)
  -- TODO: merge intersected entries
  local entries = {}
  local errs = {}
  for _, raw_entry in ipairs(raw_entries) do
    local entry, err = Entry.new(raw_entry)
    if err then
      table.insert(errs, err)
    else
      table.insert(entries, entry)
    end
  end
  if #errs > 0 then
    return entries, "[unionbuf] Invalid entries: \n" .. table.concat(errs, "\n")
  end
  return entries, nil
end

function Entry.new(raw_entry)
  local bufnr = raw_entry.bufnr
  if not bufnr then
    bufnr = vim.fn.bufadd(raw_entry.path)
    vim.fn.bufload(bufnr)
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, ("- Buffer=%d : the buffer is invalid"):format(bufnr)
  end

  local start_row = raw_entry.start_row
  local end_row = raw_entry.end_row or raw_entry.start_row
  if start_row > end_row and end_row >= 0 then
    start_row, end_row = end_row, start_row
  end

  local max_row = vim.api.nvim_buf_line_count(bufnr) - 1
  if start_row > max_row then
    return nil, ("- Buffer=%d : start_row = %d is out of range. (max_row = %d)"):format(bufnr, start_row, max_row)
  end
  if end_row > max_row then
    return nil, ("- Buffer=%d : end_row = %d is out of range. (max_row = %d)"):format(bufnr, end_row, max_row)
  end

  local start_col = raw_entry.start_col or 0
  local end_col = raw_entry.end_col or -1
  local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  if start_row == end_row and start_col > end_col and end_col >= 0 then
    start_col, end_col = end_col, start_col
  end

  local original_end_col = end_col
  if end_col == -1 then
    local last_line = lines[#lines]
    end_col = start_col + #last_line
  end

  local tbl = {
    bufnr = bufnr,
    start_row = start_row,
    end_row = end_row,
    start_col = start_col,
    end_col = end_col,
    _original_end_col = original_end_col,
    lines = lines,
  }
  return setmetatable(tbl, Entry)
end

function Entry.is_already_changed(self)
  local lines = vim.api.nvim_buf_get_text(self.bufnr, self.start_row, self.start_col, self.end_row, self.end_col, {})
  return not vim.deep_equal(lines, self.lines)
end

function Entry.is_lines(self)
  if self.start_col ~= 0 then
    return false
  end
  if self._original_end_col == -1 then
    return true
  end
  local last_line = vim.api.nvim_buf_get_lines(self.bufnr, self.end_row, self.end_row + 1, false)[1]
  return self.end_col == #last_line
end

function M.deleted_map(union_bufnr, all_extmarks)
  local extmarks = vim.iter(all_extmarks):totable()
  local detector_mark = vim.api.nvim_buf_get_extmarks(union_bufnr, M.deletion_detector_ns, 0, -1, { details = true })[1]
  table.insert(extmarks, detector_mark)

  local is_deleted = function(i, extmark)
    local start_col = extmark[3]
    local end_col = extmark[4].end_col
    if start_col ~= end_col then
      return false
    end

    local neighborhood = extmarks[i + 1] or extmarks[i - 1]
    if not neighborhood then
      return false
    end

    local start_row = extmark[2]
    return start_row == neighborhood[2] and start_col == neighborhood[3]
  end

  local deleted_map = {}
  for i, extmark in ipairs(all_extmarks) do
    deleted_map[extmark[1]] = is_deleted(i, extmark)
  end
  return deleted_map
end

return M
