local M = {}

local Entries = require("unionbuf.core.entries")

local vim = vim
local ns = Entries.ns

function M.ranges(union_bufnr, range_end_row)
  local get_row_range = M._range_generator()
  local ranges = vim
    .iter(vim.api.nvim_buf_get_extmarks(union_bufnr, ns, 0, { range_end_row or -1, -1 }, {}))
    :map(function(extmark)
      local start_row, end_row, is_deleted = get_row_range(extmark)
      if is_deleted then
        return {
          extmark_id = extmark[1],
          is_deleted = is_deleted,
        }
      end
      return {
        extmark_id = extmark[1],
        is_deleted = is_deleted,
        start_row = start_row,
        start_col = 0,
        end_row = end_row,
        end_col = -1,
      }
    end)
    :totable()

  local last_valid_range = vim.iter(ranges):rfind(function(range)
    return not range.is_deleted
  end)
  if last_valid_range then
    last_valid_range.end_row = vim.api.nvim_buf_line_count(union_bufnr) - 1
  elseif #ranges > 0 then
    if require("unionbuf.lib.buffer").has_content(union_bufnr) then
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

function M._range_generator()
  local current_row = 0
  return function(extmark)
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
end

return M
