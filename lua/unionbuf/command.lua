local M = {}

function M.open(raw_entries, raw_opts)
  local opts = require("unionbuf.core.option").new(raw_opts)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "unionbuf"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "unionbuf://" .. tostring(bufnr))

  local entries, err = require("unionbuf.core.entries").new(raw_entries)
  if err then
    error(err)
  end
  local entry_map = require("unionbuf.core.reader").read(bufnr, entries)

  vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
    buffer = bufnr,
    callback = function()
      local new_entries, warn = require("unionbuf.core.entries").new(raw_entries)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
      entry_map = require("unionbuf.core.reader").read(bufnr, new_entries)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
    buffer = bufnr,
    callback = function()
      local new_raw_entries, write_warn = require("unionbuf.core.writer").write(bufnr, entry_map)
      raw_entries = new_raw_entries
      if write_warn then
        vim.notify(write_warn, vim.log.levels.WARN)
      end

      local new_entries, warn = require("unionbuf.core.entries").new(raw_entries)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
      entry_map = require("unionbuf.core.reader").read(bufnr, new_entries)
    end,
  })

  opts.open(bufnr)
end

return M
