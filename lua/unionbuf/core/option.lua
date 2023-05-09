local vim = vim

local M = {}

local default = {
  open = function(bufnr)
    vim.cmd.tabedit()
    vim.cmd.buffer(bufnr)
  end,
}

function M.new(raw_opts)
  vim.validate({ raw_opts = { raw_opts, "table", true } })
  raw_opts = raw_opts or {}
  return vim.tbl_deep_extend("force", default, raw_opts)
end

return M
