local M = {}

local Entries = require("unionbuf.core.entries")

local ns = Entries.ns

function M.ranges(union_bufnr, range_start_row, range_end_row)
  local ranges = {}
  local extmarks = vim.api.nvim_buf_get_extmarks(
    union_bufnr,
    ns,
    { range_start_row, 0 },
    { range_end_row, -1 },
    { details = true }
  )
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
        start_col = extmark[3],
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

  local next_extmarks = vim.api.nvim_buf_get_extmarks(
    union_bufnr,
    ns,
    { start_row + 1, 0 },
    -1,
    { details = true, limit = 1 }
  )
  local next_extmark = next_extmarks[1]
  if next_extmark then
    return next_extmark[2] - 1
  end

  return vim.api.nvim_buf_line_count(union_bufnr) - 1
end

function M._deleted_map(union_bufnr, all_extmarks)
  local extmarks = vim.iter(all_extmarks):totable()
  local detector_mark =
    vim.api.nvim_buf_get_extmarks(union_bufnr, Entries.deletion_detector_ns, 0, -1, { details = true })[1]
  table.insert(extmarks, detector_mark)

  local is_deleted = function(i, extmark)
    local start_col = extmark[3]
    if start_col > 0 then
      return true
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