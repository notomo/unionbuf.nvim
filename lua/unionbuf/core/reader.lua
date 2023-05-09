local vim = vim
local hl_groups = require("unionbuf.core.highlight_group")

local M = {}

local ns = require("unionbuf.core.entries").ns

function M.read(union_bufnr, raw_entries)
  local entries = require("unionbuf.core.entries").new(raw_entries)

  local all_lines = {}
  for _, entry in ipairs(entries) do
    vim.list_extend(all_lines, entry.lines)
  end
  vim.api.nvim_buf_clear_namespace(union_bufnr, ns, 0, -1)
  vim.api.nvim_buf_set_lines(union_bufnr, 0, -1, false, all_lines)
  vim.bo[union_bufnr].modified = false

  local row = 0
  local entry_map = {}
  for i, entry in ipairs(entries) do
    local lines = entry.lines
    local end_col = #lines[#lines]
    local end_row = row + #lines - 1

    local extmark_id = vim.api.nvim_buf_set_extmark(union_bufnr, ns, row, 0, {
      end_col = end_col,
      end_row = end_row,
      right_gravity = false,
      end_right_gravity = true,
      -- TODO: user decoration provider
      hl_eol = true,
      hl_group = i % 2 == 0 and hl_groups.UnionbufBackgroundEven or hl_groups.UnionbufBackgroundOdd,
    })
    entry_map[extmark_id] = entry

    row = end_row + 1
  end

  local deletion_detector_ns = require("unionbuf.core.entries").deletion_detector_ns
  vim.api.nvim_buf_clear_namespace(union_bufnr, deletion_detector_ns, 0, -1)
  vim.api.nvim_buf_set_extmark(union_bufnr, deletion_detector_ns, row, 0, {
    end_col = 0,
    end_row = row,
    right_gravity = false,
    end_right_gravity = true,
  })

  -- TODO: keep border newline if not deleted entry

  return entry_map
end

return M
