local M = {}

function M.open(raw_entries, raw_opts)
  local opts = require("unionbuf.core.option").new(raw_opts)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "unionbuf"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "unionbuf://" .. tostring(bufnr))

  local entry_map = require("unionbuf.core.reader").read(bufnr, raw_entries)
  vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
    buffer = bufnr,
    callback = function()
      entry_map = require("unionbuf.core.reader").read(bufnr, raw_entries)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
    buffer = bufnr,
    callback = function()
      require("unionbuf.core.writer").write(bufnr, entry_map)
    end,
  })

  opts.open(bufnr)
end

return M
