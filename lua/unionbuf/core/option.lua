local vim = vim

local M = {}

local default_open_opts = {
  open = function(bufnr)
    vim.cmd.tabedit()
    vim.cmd.buffer(bufnr)
  end,
}
function M.new_open_opts(raw_opts)
  raw_opts = raw_opts or {}
  return vim.tbl_deep_extend("force", default_open_opts, raw_opts)
end

local default_get_entry_opts = {
  row = nil,
  bufnr = 0,
}
function M.new_get_entry_opts(raw_opts)
  raw_opts = raw_opts or {}
  local opts = vim.tbl_deep_extend("force", default_get_entry_opts, raw_opts)
  if opts.bufnr == 0 then
    opts.bufnr = vim.api.nvim_get_current_buf()
  end
  if not opts.row then
    opts.row = vim.api.nvim_win_get_cursor(0)[1] - 1
  end
  return opts
end

local default_shift_opts = {
  bufnr = 0,
  start_row = nil,
  end_row = nil,
}
function M.new_shift_opts(raw_opts)
  raw_opts = raw_opts or {}
  local opts = vim.tbl_deep_extend("force", default_shift_opts, raw_opts)
  if opts.bufnr == 0 then
    opts.bufnr = vim.api.nvim_get_current_buf()
  end
  if not opts.start_row then
    opts.start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  end
  if not opts.end_row then
    opts.end_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  end
  return opts
end

return M
