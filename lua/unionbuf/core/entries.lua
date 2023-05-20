local vim = vim

local M = {}

M.ns = vim.api.nvim_create_namespace("unionbuf")
M.deletion_detector_ns = vim.api.nvim_create_namespace("unionbuf_deletion_detector")

local Entry = {}
Entry.__index = Entry

function M.new(raw_entries)
  local entries, err = M._new(raw_entries)
  if err then
    return entries, err
  end

  local sorted = {}
  local groups = require("unionbuf.vendor.misclib.collection.list").group_by(entries, function(entry)
    return entry.bufnr
  end)
  for _, group in ipairs(groups) do
    local _, buffer_entries = unpack(group)
    table.sort(buffer_entries, function(a, b)
      if a.start_row == b.start_row then
        return a.end_col < b.end_col
      end
      return a.start_row < b.start_row
    end)
    vim.list_extend(sorted, M._merge(buffer_entries))
  end

  return sorted, nil
end

function M._new(raw_entries)
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

function M._merge(entries)
  local raw_entries = { entries[1] }
  local index = 1
  for entry in vim.iter(entries):skip(1) do
    local last = raw_entries[index]
    local merged = M._merge_one(last, entry)
    if merged then
      raw_entries[index] = merged
    else
      table.insert(raw_entries, entry)
      index = index + 1
    end
  end

  local new_entries, err = M._new(raw_entries)
  if err then
    error(err)
  end
  return new_entries
end

function M._merge_one(entry, next_entry)
  if entry.is_deleted or next_entry.is_deleted then
    return nil
  end
  if entry.end_row < next_entry.start_row then
    return nil
  end
  if entry.end_row == next_entry.start_row and entry.end_col < next_entry.start_col then
    return nil
  end
  return {
    bufnr = entry.bufnr,
    start_row = entry.start_row,
    start_col = entry.start_col,
    end_row = next_entry.end_row,
    end_col = next_entry.end_col,
    extmark_id = entry.extmark_id,
  }
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
  if not raw_entry.is_deleted and start_row > max_row then
    return nil, ("- Buffer=%d : start_row = %d is out of range. (max_row = %d)"):format(bufnr, start_row, max_row)
  end
  if not raw_entry.is_deleted and end_row > max_row then
    return nil, ("- Buffer=%d : end_row = %d is out of range. (max_row = %d)"):format(bufnr, end_row, max_row)
  end

  local start_col = raw_entry.start_col or 0
  local end_col = raw_entry.end_col or -1
  local is_deleted = raw_entry.is_deleted or false
  local lines
  if is_deleted then
    lines = {}
  else
    lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  end
  if start_row == end_row and start_col > end_col and end_col >= 0 then
    start_col, end_col = end_col, start_col
  end

  local original_end_col = end_col
  if end_col == -1 then
    local last_line = lines[#lines] or ""
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
    is_deleted = is_deleted,
    is_lines_before_deleted = raw_entry.is_lines_before_deleted or false,
    extmark_id = raw_entry.extmark_id,
  }
  return setmetatable(tbl, Entry)
end

function Entry.is_already_changed(self)
  if self.is_deleted then
    return not vim.deep_equal({}, self.lines)
  end
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

function Entry.height(self)
  if self.is_deleted then
    return 0
  end
  return #self.lines
end

return M
