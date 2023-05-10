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

return M
