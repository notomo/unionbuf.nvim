local vim = vim

local M = {}

local Entry = {}
Entry.__index = Entry

function M.new(raw_entries)
  local resolved = require("unionbuf.core.buffer_resolver").resolve(raw_entries)
  if type(resolved) == "string" then
    local err = resolved
    return err
  end

  local entries = M._new(raw_entries, resolved)
  local groups = require("unionbuf.vendor.misclib.collection.list").group_by(entries, function(entry)
    return entry.bufnr
  end)

  local sorted = {}
  for _, group in ipairs(groups) do
    local _, buffer_entries = unpack(group)
    table.sort(buffer_entries, function(a, b)
      if a.start_row == b.start_row then
        return a.end_col < b.end_col
      end
      return a.start_row < b.start_row
    end)
    vim.list_extend(sorted, M._merge(buffer_entries, resolved))
  end
  return sorted
end

function M._new(raw_entries, resolved)
  local entries = {}
  for _, raw_entry in ipairs(raw_entries) do
    local entry = Entry.new(raw_entry, resolved)
    table.insert(entries, entry)
  end
  return entries
end

function M._merge(entries, resolved)
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
  return M._new(raw_entries, resolved)
end

function M._merge_one(entry, next_entry)
  if entry.is_deleted or next_entry.is_deleted then
    return nil
  end
  if entry.end_row + 1 < next_entry.start_row then
    return nil
  end
  if entry.end_row == next_entry.start_row and entry.end_col < next_entry.start_col then
    return nil
  end
  if
    entry.end_row + 1 == next_entry.start_row and not (next_entry.start_col == 0 and Entry._contain_end_of_line(entry))
  then
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

function Entry.new(raw_entry, resolved)
  local bufnr = raw_entry.bufnr
  if not bufnr then
    bufnr = resolved.path_to_bufnr[raw_entry.path]
  end

  local start_row = raw_entry.start_row
  local end_row = raw_entry.end_row or raw_entry.start_row
  local max_row = resolved.bufnr_to_info[bufnr].max_row
  if not raw_entry.is_deleted and start_row > max_row then
    start_row = max_row
  end
  if not raw_entry.is_deleted and end_row > max_row then
    end_row = max_row
  end

  local start_col = raw_entry.start_col or 0
  local end_col = raw_entry.end_col or -1
  local is_deleted = raw_entry.is_deleted or false
  local lines = M._lines(bufnr, start_row, start_col, end_row, end_col, is_deleted)

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
  local lines = M._lines(self.bufnr, self.start_row, self.start_col, self.end_row, self.end_col, self.is_deleted)
  return not vim.deep_equal(lines, self.lines)
end

function Entry.is_lines(self)
  if self.start_col ~= 0 then
    return false
  end
  return self:_contain_end_of_line()
end

function Entry._contain_end_of_line(self)
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

function M.lines(entries)
  local is_deleted_all = vim.iter(entries):all(function(entry)
    return entry.is_deleted
  end)
  if is_deleted_all then
    return { "" }
  end

  return vim.iter(entries):fold({}, function(t, entry)
    vim.list_extend(t, entry.lines)
    return t
  end)
end

function M._lines(bufnr, start_row, start_col, end_row, end_col, is_deleted)
  if is_deleted then
    return {}
  end
  return vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
end

return M
