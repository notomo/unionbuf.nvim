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

local get_lines = function(entry)
  return vim.api.nvim_buf_get_text(entry.bufnr, entry.start_row, entry.start_col, entry.end_row, entry.end_col, {})
end

local is_lines = function(entry)
  if entry.start_col ~= 0 then
    return false
  end
  if entry.end_col == -1 then
    return true
  end
  local last_line = vim.api.nvim_buf_get_lines(entry.bufnr, entry.end_row, entry.end_row + 1, false)[1]
  return entry.end_col == #last_line
end

function Entry.new(raw_entry)
  local default = {
    end_row = raw_entry.start_row,
    start_col = 0,
    end_col = -1,
  }
  local entry = vim.tbl_deep_extend("force", default, raw_entry)

  if entry.start_row > entry.end_row and entry.end_row >= 0 then
    local start_row = entry.start_row
    local end_row = entry.end_row
    entry.start_row = end_row
    entry.end_row = start_row
  end

  if entry.start_row == entry.end_row and entry.start_col > entry.end_col and entry.end_col >= 0 then
    local start_col = entry.start_col
    local end_col = entry.end_col
    entry.start_col = end_col
    entry.end_col = start_col
  end

  if not entry.bufnr then
    local bufnr = vim.fn.bufadd(entry.path)
    vim.fn.bufload(bufnr)
    entry.bufnr = bufnr
  end

  entry.lines = get_lines(entry)
  entry.is_lines = is_lines(entry)

  if entry.end_col == -1 then
    local last_line = entry.lines[#entry.lines]
    entry.end_col = entry.start_col + #last_line
  end

  return setmetatable(entry, Entry)
end

function Entry.is_already_changed(self)
  local lines = get_lines(self)
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
