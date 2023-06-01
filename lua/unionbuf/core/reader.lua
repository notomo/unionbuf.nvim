local vim = vim
local hl_groups = require("unionbuf.core.highlight_group")

local M = {}

local ns = require("unionbuf.core.extmark").ns

function M.read(union_bufnr, entries)
  vim.api.nvim_buf_clear_namespace(union_bufnr, ns, 0, -1)

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

local decoration_ns = vim.api.nvim_create_namespace("unionbuf_decoration")
vim.api.nvim_set_decoration_provider(decoration_ns, {})
vim.api.nvim_set_decoration_provider(decoration_ns, {
  on_buf = function(_, bufnr)
    return vim.bo[bufnr].filetype == "unionbuf"
  end,
  on_win = function(_, _, bufnr, topline, botline_guess)
    if vim.bo[bufnr].filetype ~= "unionbuf" then
      return false
    end
    local extmark_ranges = vim
      .iter(require("unionbuf.core.extmark").ranges(bufnr, botline_guess))
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
        hl_eol = true,
        hl_group = count % 2 == 0 and hl_groups.UnionbufBackgroundEven or hl_groups.UnionbufBackgroundOdd,
        ephemeral = true,
      })
    end)
  end,
})

return M
