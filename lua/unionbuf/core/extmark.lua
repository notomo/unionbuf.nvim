local M = {}

local Entries = require("unionbuf.core.entries")

local ns = Entries.ns

function M.ranges(union_bufnr, range_end_row)
  local current_row = 0
  local to_row = function(extmark)
    local row = extmark[2]
    local column = extmark[3]
    if row == current_row and column == 0 then
      return nil, nil, true
    end

    local current_start_row = current_row

    if row == current_row and column > 0 then
      current_row = row + 1
      return current_start_row, row, false
    end

    current_row = row
    return current_start_row, row - 1, false
  end

  local ranges = {}
  local last_range_index = 0
  local extmarks = vim.api.nvim_buf_get_extmarks(union_bufnr, ns, 0, { range_end_row or -1, -1 }, {})
  for i, extmark in ipairs(extmarks) do
    local start_row, end_row, is_deleted = to_row(extmark)
    local extmark_id = extmark[1]
    local range
    if is_deleted then
      range = {
        extmark_id = extmark_id,
        is_deleted = is_deleted,
      }
    else
      range = {
        extmark_id = extmark_id,
        is_deleted = is_deleted,
        start_row = start_row,
        start_col = 0,
        end_row = end_row,
        end_col = -1,
      }
      last_range_index = i
    end
    table.insert(ranges, range)
  end

  if ranges[last_range_index] then
    ranges[last_range_index].end_row = vim.api.nvim_buf_line_count(union_bufnr) - 1
  elseif #ranges > 0 then
    local lines = vim.api.nvim_buf_get_text(union_bufnr, 0, 0, 0, 1, {})
    if #lines == 1 and lines[1] ~= "" then
      ranges[#ranges] = {
        extmark_id = ranges[#ranges].extmark_id,
        is_deleted = false,
        start_row = 0,
        start_col = 0,
        end_row = vim.api.nvim_buf_line_count(union_bufnr) - 1,
        end_col = -1,
      }
    end
  end

  return ranges
end

return M
