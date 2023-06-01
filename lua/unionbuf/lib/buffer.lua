local M = {}

function M.has_content(bufnr)
  local char = vim.api.nvim_buf_get_text(bufnr, 0, 0, 0, 1, {})[1]
  if not char then
    -- for example unloaded buffer
    return false
  end
  return char ~= ""
end

return M
