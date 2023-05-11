local vim = vim

local M = {}

local ns = require("unionbuf.core.entries").ns
local tracker_ns = vim.api.nvim_create_namespace("unionbuf_tracker")

function M.write(union_bufnr, entry_map)
  local all_extmarks = vim.api.nvim_buf_get_extmarks(union_bufnr, ns, 0, -1, { details = true })
  local deleted_map = M._deleted_map(union_bufnr, all_extmarks)
  local all_entry_pairs = vim.tbl_map(function(extmark)
    local extmark_id = extmark[1]
    return {
      extmark = extmark,
      entry = entry_map[extmark_id],
      is_deleted = deleted_map[extmark_id],
    }
  end, all_extmarks)

  local groups = require("unionbuf.vendor.misclib.collection.list").group_by(all_entry_pairs, function(pair)
    return pair.entry.bufnr
  end)
  local changed_bufnrs = {}
  for _, group in ipairs(groups) do
    local entry_bufnr, entry_pairs = unpack(group)
    table.sort(entry_pairs, function(a, b)
      return a.entry.end_row > b.entry.end_row
    end)

    for _, pair in ipairs(entry_pairs) do
      local entry = pair.entry
      if not pair.is_deleted then
        vim.api.nvim_buf_set_extmark(entry_bufnr, tracker_ns, entry.start_row, entry.start_col, {
          end_row = entry.end_row,
          end_col = entry.end_col,
          right_gravity = false,
          end_right_gravity = true,
        })
      end

      local changed = M._set_text(union_bufnr, entry, pair.extmark, pair.is_deleted)
      changed_bufnrs[entry_bufnr] = changed_bufnrs[entry_bufnr] or changed

      if pair.is_deleted then
        vim.api.nvim_buf_del_extmark(union_bufnr, ns, pair.extmark[1])
      end
    end
  end

  local bufnrs = vim
    .iter(groups)
    :map(function(group)
      local entry_bufnr = group[1]
      if not changed_bufnrs[entry_bufnr] then
        return nil
      end
      return entry_bufnr
    end)
    :totable()
  M._write(bufnrs)
  vim.bo[union_bufnr].modified = false

  local new_raw_entries = {}
  for _, group in ipairs(groups) do
    local entry_bufnr, entry_pairs = unpack(group)
    local raw_entries
    if changed_bufnrs[entry_bufnr] then
      local tracker_extmarks = vim.api.nvim_buf_get_extmarks(entry_bufnr, tracker_ns, 0, -1, { details = true })
      raw_entries = vim.tbl_map(function(extmark)
        return {
          bufnr = entry_bufnr,
          start_row = extmark[2],
          start_col = extmark[3],
          end_row = extmark[4].end_row,
          end_col = extmark[4].end_col,
        }
      end, tracker_extmarks)
    else
      raw_entries = vim.tbl_map(function(entry_pair)
        local entry = entry_pair.entry
        return {
          bufnr = entry_bufnr,
          start_row = entry.start_row,
          start_col = entry.start_col,
          end_row = entry.end_row,
          end_col = entry.end_col,
        }
      end, entry_pairs)
    end
    vim.list_extend(new_raw_entries, raw_entries)
    vim.api.nvim_buf_clear_namespace(entry_bufnr, tracker_ns, 0, -1)
  end
  return new_raw_entries
end

function M._set_text(union_bufnr, entry, extmark, is_deleted)
  if entry:is_already_changed() then
    local msg = ("[unionbuf] Original buffer(bufnr=%d, start_row=%d) has already changed."):format(
      entry.bufnr,
      entry.start_row
    )
    vim.notify(msg, vim.log.levels.WARN)
    return false
  end

  local start_row = extmark[2]
  local start_col = extmark[3]

  local end_row = extmark[4].end_row
  local end_col = extmark[4].end_col
  local max_row = vim.api.nvim_buf_line_count(union_bufnr) - 1
  if end_row > max_row then
    -- nvim_buf_get_text is end_row inclusive
    end_row = max_row
    end_col = -1
  end

  local lines
  if is_deleted then
    lines = {}
  else
    lines = vim.api.nvim_buf_get_text(union_bufnr, start_row, start_col, end_row, end_col, {})
  end
  if vim.deep_equal(lines, entry.lines) then
    return false
  end

  if entry.is_lines and is_deleted then
    vim.api.nvim_buf_set_lines(entry.bufnr, entry.start_row, entry.end_row + 1, false, {})
  else
    vim.api.nvim_buf_set_text(entry.bufnr, entry.start_row, entry.start_col, entry.end_row, entry.end_col, lines)
  end

  return true
end

function M._write(bufnrs)
  for _, bufnr in ipairs(bufnrs) do
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd.update()
    end)
  end
end

function M._deleted_map(union_bufnr, all_extmarks)
  local extmarks = vim.deepcopy(all_extmarks)
  local detector_mark = vim.api.nvim_buf_get_extmarks(
    union_bufnr,
    require("unionbuf.core.entries").deletion_detector_ns,
    0,
    -1,
    { details = true }
  )[1]
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
    local end_row = extmark[4].end_row
    return start_row == neighborhood[2] and end_row == neighborhood[4].end_row and start_col == neighborhood[3]
  end

  local deleted_map = {}
  for i, extmark in ipairs(all_extmarks) do
    deleted_map[extmark[1]] = is_deleted(i, extmark)
  end
  return deleted_map
end

return M
