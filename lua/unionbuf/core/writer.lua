local vim = vim

local M = {}

local tracker_ns = vim.api.nvim_create_namespace("unionbuf_tracker")

function M.write(union_bufnr, entry_map)
  local extmark_ranges = require("unionbuf.core.extmark").ranges(union_bufnr, -1)
  local all_entry_pairs = vim
    .iter(extmark_ranges)
    :map(function(extmark_range)
      return {
        extmark_range = extmark_range,
        entry = entry_map[extmark_range.extmark_id],
      }
    end)
    :totable()

  local groups = require("unionbuf.vendor.misclib.collection.list").group_by(all_entry_pairs, function(pair)
    return pair.entry.bufnr
  end)
  local changed_bufnrs = {}
  local all_tracked_map = {}
  local warns = {}
  for _, group in ipairs(groups) do
    local entry_bufnr, entry_pairs = unpack(group)

    local reversed_pairs = vim.iter(entry_pairs):totable()
    table.sort(reversed_pairs, function(a, b)
      if a.entry.end_row == b.entry.end_row then
        return a.entry.end_col > b.entry.end_col
      end
      return a.entry.end_row > b.entry.end_row
    end)

    local tracked_map = {}
    for _, pair in ipairs(reversed_pairs) do
      local extmark_range = pair.extmark_range
      local entry = pair.entry
      local tracker_id, changed, is_lines_before_deleted, warn = M._set_text(union_bufnr, extmark_range, entry)
      changed_bufnrs[entry_bufnr] = changed_bufnrs[entry_bufnr] or changed
      tracked_map[tracker_id] = {
        extmark_range = extmark_range,
        changed = changed,
        is_lines_before_deleted = is_lines_before_deleted,
      }
      if warn then
        table.insert(warns, warn)
      end
    end
    all_tracked_map[entry_bufnr] = tracked_map
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
    local tracked_map = all_tracked_map[entry_bufnr]
    local raw_entries
    if changed_bufnrs[entry_bufnr] then
      local tracker_extmarks = vim.api.nvim_buf_get_extmarks(entry_bufnr, tracker_ns, 0, -1, { details = true })
      raw_entries = vim
        .iter(tracker_extmarks)
        :map(function(extmark)
          local tracked = tracked_map[extmark[1]]
          return {
            bufnr = entry_bufnr,
            start_row = extmark[2],
            start_col = extmark[3],
            end_row = extmark[4].end_row,
            end_col = extmark[4].end_col,
            is_deleted = tracked.extmark_range.is_deleted,
            extmark_id = tracked.extmark_range.extmark_id,
            is_lines_before_deleted = tracked.is_lines_before_deleted,
          }
        end)
        :totable()
    else
      raw_entries = vim.tbl_map(function(entry_pair)
        return entry_pair.entry
      end, entry_pairs)
    end
    vim.list_extend(new_raw_entries, raw_entries)
    vim.api.nvim_buf_clear_namespace(entry_bufnr, tracker_ns, 0, -1)
  end

  if #warns > 0 then
    return new_raw_entries, table.concat(warns, "\n")
  end
  return new_raw_entries, nil
end

function M._set_text(union_bufnr, extmark_range, entry)
  local tracker_id = vim.api.nvim_buf_set_extmark(entry.bufnr, tracker_ns, entry.start_row, entry.start_col, {
    end_row = entry.end_row,
    end_col = entry.end_col,
    right_gravity = entry.is_deleted,
    end_right_gravity = true,
  })

  if entry:is_already_changed() then
    local warn = ("[unionbuf] Original buffer(bufnr=%d, start_row=%d) has already changed."):format(
      entry.bufnr,
      entry.start_row
    )
    return tracker_id, false, entry.is_lines_before_deleted, warn
  end

  local lines
  if extmark_range.is_deleted then
    lines = {}
  else
    lines = vim.api.nvim_buf_get_text(
      union_bufnr,
      extmark_range.start_row,
      extmark_range.start_col,
      extmark_range.end_row,
      extmark_range.end_col,
      {}
    )
  end
  if vim.deep_equal(lines, entry.lines) then
    return tracker_id, false, entry.is_lines_before_deleted
  end

  local is_lines_before_deleted = false
  if entry.is_lines_before_deleted then
    vim.api.nvim_buf_set_lines(entry.bufnr, entry.start_row, entry.end_row, false, lines)
    vim.api.nvim_buf_set_extmark(entry.bufnr, tracker_ns, entry.start_row, entry.start_col, {
      id = tracker_id,
      end_row = entry.start_row + #lines - 1,
      end_col = #lines[#lines],
      right_gravity = true,
      end_right_gravity = true,
    })
  elseif extmark_range.is_deleted and entry:is_lines() then
    vim.api.nvim_buf_set_lines(entry.bufnr, entry.start_row, entry.end_row + 1, false, {})
    is_lines_before_deleted = true
  else
    vim.api.nvim_buf_set_text(entry.bufnr, entry.start_row, entry.start_col, entry.end_row, entry.end_col, lines)
  end

  return tracker_id, true, is_lines_before_deleted
end

return M
