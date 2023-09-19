local vim = vim
local hl_groups = require("unionbuf.core.highlight_group")

local M = {}

local ns = require("unionbuf.core.extmark").ns

function M.read(union_bufnr, entries)
  vim.api.nvim_buf_clear_namespace(union_bufnr, ns, 0, -1)

  local first_bufnr = (entries[1] or {}).bufnr
  if first_bufnr then
    vim.bo[union_bufnr].expandtab = vim.bo[first_bufnr].expandtab
  end

  local entries_lines = require("unionbuf.core.entries").lines(entries)
  local current_lines = vim.api.nvim_buf_get_lines(union_bufnr, 0, -1, false)
  if not vim.deep_equal(entries_lines, current_lines) then
    vim.api.nvim_buf_set_lines(union_bufnr, 0, -1, false, entries_lines)
    vim.bo[union_bufnr].modified = false
    require("unionbuf.lib.undo").clear(union_bufnr)
  end

  local row = 0
  local entry_map = {}
  for _, entry in ipairs(entries) do
    row = row + entry:height()
    local extmark_id = vim.api.nvim_buf_set_extmark(union_bufnr, ns, row, 0, {
      id = entry.extmark_id,
      right_gravity = false,
    })
    entry_map[extmark_id] = entry
  end
  return entry_map
end

function M.get(bufnr, entry_map, row)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, -1 }, -1, {})
  for _, extmark in ipairs(extmarks) do
    local extmark_id = extmark[1]
    local entry = entry_map[extmark_id]
    if entry and not entry.is_deleted then
      return {
        bufnr = entry.bufnr,
        start_row = entry.start_row,
        end_row = entry.end_row,
        start_col = entry.start_col,
        end_col = entry.end_col,
      }
    end
  end
  return nil
end

function M.shift(bufnr, entry_map, start_row, end_row, offsets)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
  local entry_pairs = vim
    .iter(extmarks)
    :map(function(extmark)
      local extmark_id = extmark[1]
      local entry = entry_map[extmark_id]
      if not entry then
        return nil
      end
      return {
        extmark = extmark,
        entry = entry,
      }
    end)
    :totable()

  local start_index = #entry_pairs
  for i, pair in ipairs(entry_pairs) do
    local row = pair.extmark[2]
    if start_row < row then
      start_index = i
      break
    end
  end

  local end_index = #entry_pairs
  for i, pair in ipairs(entry_pairs) do
    local row = pair.extmark[2]
    if end_row < row then
      end_index = i
      break
    end
  end

  local entries = vim
    .iter(entry_pairs)
    :map(function(pair)
      return pair.entry
    end)
    :totable()

  local new_raw_entries = {}

  local start_side_part = vim.list_slice(entries, 1, start_index - 1)
  vim.list_extend(new_raw_entries, start_side_part)

  local modified_part = vim
    .iter(vim.list_slice(entries, start_index, end_index))
    :map(function(entry)
      if entry.is_deleted then
        return entry
      end

      entry.start_row = math.max(0, entry.start_row + offsets.start_row)
      entry.end_row = math.max(entry.start_row, entry.end_row + offsets.end_row)

      return entry
    end)
    :totable()
  vim.list_extend(new_raw_entries, modified_part)

  local end_side_part = vim.list_slice(entries, end_index + 1)
  vim.list_extend(new_raw_entries, end_side_part)

  return new_raw_entries
end

local decoration_ns = vim.api.nvim_create_namespace("unionbuf_decoration")
local priority = vim.highlight.priorities.user - 1
vim.api.nvim_set_decoration_provider(decoration_ns, {})
vim.api.nvim_set_decoration_provider(decoration_ns, {
  on_buf = function(_, bufnr)
    return vim.bo[bufnr].filetype == "unionbuf"
  end,
  on_win = function(_, window_id, bufnr, topline, botline_guess)
    if vim.bo[bufnr].filetype ~= "unionbuf" then
      return false
    end
    local height = vim.api.nvim_win_get_height(window_id)
    local extmark_ranges = vim
      -- NOTE: +height is workaround for robust odd/even highlight
      .iter(require("unionbuf.core.extmark").ranges(bufnr, botline_guess + height))
      :filter(function(extmark_range)
        return not extmark_range.is_deleted
      end)

    if not extmark_ranges:peek() then
      vim.api.nvim_buf_set_extmark(bufnr, decoration_ns, 0, 0, {
        virt_text = { { "(no entries)", hl_groups.UnionbufNoEntries } },
        ephemeral = true,
      })
      return
    end

    local count = 0
    extmark_ranges:each(function(extmark_range)
      count = count + 1
      if extmark_range.end_row < topline then
        return
      end

      vim.api.nvim_buf_set_extmark(bufnr, decoration_ns, extmark_range.start_row, 0, {
        end_col = 0,
        end_row = extmark_range.end_row + 1,
        priority = priority,
        hl_eol = true,
        hl_group = count % 2 == 0 and hl_groups.UnionbufBackgroundEven or hl_groups.UnionbufBackgroundOdd,
        ephemeral = true,
      })
    end)
  end,
})

return M
