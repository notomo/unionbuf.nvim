local vim = vim
local hl_groups = require("unionbuf.core.highlight_group")
local Entries = require("unionbuf.core.entries")

local M = {}

local ns = Entries.ns

function M.read(union_bufnr, entries)
  vim.api.nvim_buf_clear_namespace(union_bufnr, ns, 0, -1)

  local all_lines = vim.iter(entries):fold({}, function(t, entry)
    vim.list_extend(t, entry.lines)
    return t
  end)
  local current_lines = vim.api.nvim_buf_get_lines(union_bufnr, 0, -1, false)
  if not vim.deep_equal(all_lines, current_lines) then
    vim.api.nvim_buf_set_lines(union_bufnr, 0, -1, false, all_lines)
    vim.bo[union_bufnr].modified = false
    require("unionbuf.lib.undo").clear(union_bufnr)
  end

  local row = 0
  local entry_map = {}
  for _, entry in ipairs(entries) do
    local extmark_id = vim.api.nvim_buf_set_extmark(union_bufnr, ns, row, 0, {
      right_gravity = false,
    })
    entry_map[extmark_id] = entry
    row = row + #entry.lines
  end

  local deletion_detector_ns = Entries.deletion_detector_ns
  vim.api.nvim_buf_clear_namespace(union_bufnr, deletion_detector_ns, 0, -1)
  vim.api.nvim_buf_set_extmark(union_bufnr, deletion_detector_ns, row, 0, {
    right_gravity = false,
  })

  return entry_map
end

local highlight_ns = vim.api.nvim_create_namespace("unionbuf_highlight")
vim.api.nvim_set_decoration_provider(highlight_ns, {})
vim.api.nvim_set_decoration_provider(highlight_ns, {
  on_buf = function(_, bufnr)
    return vim.bo[bufnr].filetype == "unionbuf"
  end,
  on_win = function(_, _, bufnr, topline, botline_guess)
    if vim.bo[bufnr].filetype ~= "unionbuf" then
      return false
    end
    local count = 1
    local extmark_ranges = require("unionbuf.core.extmark").ranges(bufnr, topline, botline_guess)
    vim
      .iter(extmark_ranges)
      :filter(function(extmark_range)
        return not extmark_range.is_deleted
      end)
      :each(function(extmark_range)
        vim.api.nvim_buf_set_extmark(bufnr, ns, extmark_range.start_row, extmark_range.start_col, {
          end_col = 0,
          end_row = extmark_range.end_row + 1,
          hl_eol = true,
          hl_group = count % 2 == 0 and hl_groups.UnionbufBackgroundEven or hl_groups.UnionbufBackgroundOdd,
          ephemeral = true,
        })
        count = count + 1
      end)
  end,
})

return M
