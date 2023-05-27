local M = {}

local Entries = require("unionbuf.core.entries")

local ns = Entries.ns

function M.ranges(union_bufnr, range_start_row, range_end_row)
  local ranges = {}
  local extmarks = vim.api.nvim_buf_get_extmarks(union_bufnr, ns, { range_start_row, 0 }, { range_end_row, -1 }, {})
  local deleted_map = M._deleted_map(union_bufnr, extmarks)
  for i, extmark in ipairs(extmarks) do
    local extmark_id = extmark[1]
    local is_deleted = deleted_map[extmark_id]
    local range
    if is_deleted then
      range = {
        extmark_id = extmark_id,
        is_deleted = is_deleted,
      }
    else
      local start_row = extmark[2]
      range = {
        extmark_id = extmark_id,
        is_deleted = is_deleted,
        start_row = start_row,
        start_col = 0,
        end_row = M._end_row(union_bufnr, extmarks, i, start_row, deleted_map),
        end_col = -1,
      }
    end
    table.insert(ranges, range)
  end
  return ranges
end

function M._end_row(union_bufnr, extmarks, i, start_row, deleted_map)
  local extmark = extmarks[i + 1]
  if extmark and not deleted_map[extmark[1]] then
    return extmark[2] - 1
  end

  local next_extmarks = vim.api.nvim_buf_get_extmarks(union_bufnr, ns, { start_row + 1, 0 }, -1, { limit = 1 })
  local next_extmark = next_extmarks[1]
  if next_extmark then
    return next_extmark[2] - 1
  end

  return vim.api.nvim_buf_line_count(union_bufnr) - 1
end

function M._deleted_map(union_bufnr, extmarks)
  local detector = vim.api.nvim_buf_get_extmarks(union_bufnr, Entries.deletion_detector_ns, 0, -1, {})[1]

  local is_deleted = function(i, extmark)
    local start_col = extmark[3]
    if start_col > 0 then
      return true
    end

    local start_row = extmark[2]
    local neighborhood = extmarks[i + 1]
    if neighborhood then
      return start_row == neighborhood[2] and start_col == neighborhood[3]
    end

    local max_row = vim.api.nvim_buf_line_count(union_bufnr)
    if max_row < start_row + 1 then
      return true
    end

    local lines = vim.api.nvim_buf_get_lines(union_bufnr, start_row, -1, {})
    return start_row == detector[2]
      and start_col == detector[3]
      and (#lines == 0 or (max_row == 1 and #lines == 1 and lines[1] == ""))
  end

  local deleted_map = {}
  for i, extmark in ipairs(extmarks) do
    deleted_map[extmark[1]] = is_deleted(i, extmark)
  end
  return deleted_map
end

return M
