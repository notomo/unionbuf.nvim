local vim = vim
local hl_groups = require("unionbuf.core.highlight_group")
local Entries = require("unionbuf.core.entries")

local M = {}

local ns = Entries.ns

function M.read(union_bufnr, raw_entries)
  local entries = Entries.new(raw_entries)

  local all_lines = {}
  for _, entry in ipairs(entries) do
    vim.list_extend(all_lines, entry.lines)
  end
  vim.api.nvim_buf_clear_namespace(union_bufnr, ns, 0, -1)
  vim.api.nvim_buf_set_lines(union_bufnr, 0, -1, false, all_lines)
  vim.bo[union_bufnr].modified = false

  local row = 0
  local entry_map = {}
  for _, entry in ipairs(entries) do
    local lines = entry.lines
    local end_col = #lines[#lines]
    local end_row = row + #lines - 1

    local extmark_id = vim.api.nvim_buf_set_extmark(union_bufnr, ns, row, 0, {
      end_col = end_col,
      end_row = end_row,
      right_gravity = false,
      end_right_gravity = true,
    })
    entry_map[extmark_id] = entry

    row = end_row + 1
  end

  local deletion_detector_ns = Entries.deletion_detector_ns
  vim.api.nvim_buf_clear_namespace(union_bufnr, deletion_detector_ns, 0, -1)
  vim.api.nvim_buf_set_extmark(union_bufnr, deletion_detector_ns, row, 0, {
    end_col = 0,
    end_row = row,
    right_gravity = false,
    end_right_gravity = true,
  })

  -- TODO: keep border newline if not deleted entry

  -- Current limitation: This disturbs undo after writing. Because it may break extmark position.
  require("unionbuf.lib.undo").clear(union_bufnr)

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
    local all_extmarks = vim.api.nvim_buf_get_extmarks(
      bufnr,
      ns,
      { topline, 0 },
      { botline_guess, -1 },
      { details = true }
    )
    local count = 1
    local deleted_map = Entries.deleted_map(bufnr, all_extmarks)
    for _, extmark in ipairs(all_extmarks) do
      if not deleted_map[extmark[1]] then
        vim.api.nvim_buf_set_extmark(bufnr, ns, extmark[2], extmark[3], {
          end_col = extmark[4].end_col,
          end_row = extmark[4].end_row,
          hl_eol = true,
          hl_group = count % 2 == 0 and hl_groups.UnionbufBackgroundEven or hl_groups.UnionbufBackgroundOdd,
          ephemeral = true,
        })
        count = count + 1
      end
    end
  end,
})

return M
