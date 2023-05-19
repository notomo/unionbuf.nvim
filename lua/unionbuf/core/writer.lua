local vim = vim

local M = {}

local ns = require("unionbuf.core.entries").ns
local tracker_ns = vim.api.nvim_create_namespace("unionbuf_tracker")

function M.write(union_bufnr, entry_map)
  local ranges = require("unionbuf.core.extmark").ranges(union_bufnr, 0, -1)
  local all_entry_pairs = vim.tbl_map(function(range)
    return {
      range = range,
      entry = entry_map[range.extmark_id],
    }
  end, ranges)

  local groups = require("unionbuf.vendor.misclib.collection.list").group_by(all_entry_pairs, function(pair)
    return pair.entry.bufnr
  end)
  local changed_bufnrs = {}
  for _, group in ipairs(groups) do
    local entry_bufnr, entry_pairs = unpack(group)

    local reversed_pairs = vim.iter(entry_pairs):totable()
    table.sort(reversed_pairs, function(a, b)
      if a.entry.end_row == b.entry.end_row then
        return a.entry.end_col > b.entry.end_col
      end
      return a.entry.end_row > b.entry.end_row
    end)
    for _, pair in ipairs(reversed_pairs) do
      local range = pair.range
      local entry = pair.entry
      if not range.is_deleted then
        vim.api.nvim_buf_set_extmark(entry_bufnr, tracker_ns, entry.start_row, entry.start_col, {
          end_row = entry.end_row,
          end_col = entry.end_col,
          right_gravity = false,
          end_right_gravity = true,
        })
      end

      local changed = M._set_text(union_bufnr, range, entry)
      changed_bufnrs[entry_bufnr] = changed_bufnrs[entry_bufnr] or changed

      if range.is_deleted then
        vim.api.nvim_buf_del_extmark(union_bufnr, ns, range.extmark_id)
      end
    end
  end

  vim
    .iter(groups)
    :map(function(group)
      local entry_bufnr = group[1]
      if not changed_bufnrs[entry_bufnr] then
        return nil
      end
      return entry_bufnr
    end)
    :each(function(bufnr)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd.update()
      end)
    end)
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
        return entry_pair.entry
      end, entry_pairs)
    end
    vim.list_extend(new_raw_entries, raw_entries)
    vim.api.nvim_buf_clear_namespace(entry_bufnr, tracker_ns, 0, -1)
  end
  return new_raw_entries
end

function M._set_text(union_bufnr, range, entry)
  if entry:is_already_changed() then
    local msg = ("[unionbuf] Original buffer(bufnr=%d, start_row=%d) has already changed."):format(
      entry.bufnr,
      entry.start_row
    )
    vim.notify(msg, vim.log.levels.WARN)
    return false
  end

  local lines
  if range.is_deleted then
    lines = {}
  else
    lines = vim.api.nvim_buf_get_text(union_bufnr, range.start_row, range.start_col, range.end_row, range.end_col, {})
  end
  if vim.deep_equal(lines, entry.lines) then
    return false
  end

  if range.is_deleted and entry:is_lines() then
    vim.api.nvim_buf_set_lines(entry.bufnr, entry.start_row, entry.end_row + 1, false, {})
  else
    vim.api.nvim_buf_set_text(entry.bufnr, entry.start_row, entry.start_col, entry.end_row, entry.end_col, lines)
  end

  return true
end

return M
