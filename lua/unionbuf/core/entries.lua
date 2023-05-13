local vim = vim

local M = {}

M.ns = vim.api.nvim_create_namespace("unionbuf")
M.deletion_detector_ns = vim.api.nvim_create_namespace("unionbuf_deletion_detector")

local Entry = {}
Entry.__index = Entry

function M.new(raw_entries)
  -- TODO: merge intersected entries
  return vim.tbl_map(function(raw_entry)
    return Entry.new(raw_entry)
  end, raw_entries)
end

local is_lines = function(bufnr, row, start_col, end_col)
  if start_col ~= 0 then
    return false
  end
  if end_col == -1 then
    return true
  end
  local last_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  return end_col == #last_line
end

function Entry.new(raw_entry)
  local bufnr = raw_entry.bufnr
  if not bufnr then
    bufnr = vim.fn.bufadd(raw_entry.path)
    vim.fn.bufload(bufnr)
  end

  local start_row = raw_entry.start_row
  local end_row = raw_entry.end_row or raw_entry.start_row
  if start_row > end_row and end_row >= 0 then
    start_row, end_row = end_row, start_row
  end

  local start_col = raw_entry.start_col or 0
  local end_col = raw_entry.end_col or -1
  local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  if start_row == end_row and start_col > end_col and end_col >= 0 then
    start_col, end_col = end_col, start_col
  end
  if end_col == -1 then
    local last_line = lines[#lines]
    end_col = start_col + #last_line
  end

  local entry = {
    bufnr = bufnr,
    start_row = start_row,
    end_row = end_row,
    start_col = start_col,
    end_col = end_col,
    lines = lines,
    is_lines = is_lines(bufnr, end_row, start_col, end_col),
  }
  return setmetatable(entry, Entry)
end

function Entry.is_already_changed(self)
  local lines = vim.api.nvim_buf_get_text(self.bufnr, self.start_row, self.start_col, self.end_row, self.end_col, {})
  return not vim.deep_equal(lines, self.lines)
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
