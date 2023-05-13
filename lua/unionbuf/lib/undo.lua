local M = {}

function M.clear(bufnr)
  local undolevels = vim.bo[bufnr].undolevels
  vim.bo[bufnr].undolevels = -1
  vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { " " })
  vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 1, { "" })
  vim.bo[bufnr].undolevels = undolevels
  vim.bo[bufnr].modified = false
end

return M
