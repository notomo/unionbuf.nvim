local M = {}

function M.has_content(bufnr)
  local count = vim.api.nvim_buf_line_count(bufnr)
  if count > 1 then
    return true
  end

  local char = vim.api.nvim_buf_get_text(bufnr, 0, 0, 0, 1, {})[1]
  if char and char ~= "" then
    return true
  end

  -- for example unloaded buffer
  return false
end

return M
