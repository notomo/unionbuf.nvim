local M = {}

local buffer_entry_maps = {}

function M.open(raw_entries, raw_opts)
  local opts = require("unionbuf.core.option").new_open_opts(raw_opts)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "unionbuf"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "unionbuf://" .. tostring(bufnr))

  local entries, err = require("unionbuf.core.entries").new(raw_entries)
  if err then
    error(err)
  end
  buffer_entry_maps[bufnr] = require("unionbuf.core.reader").read(bufnr, entries)

  vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
    buffer = bufnr,
    callback = function()
      local new_entries, warn = require("unionbuf.core.entries").new(raw_entries)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
      buffer_entry_maps[bufnr] = require("unionbuf.core.reader").read(bufnr, new_entries)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
    buffer = bufnr,
    callback = function()
      local entry_map = buffer_entry_maps[bufnr]
      local new_raw_entries, write_warn = require("unionbuf.core.writer").write(bufnr, entry_map)
      raw_entries = new_raw_entries
      if write_warn then
        vim.notify(write_warn, vim.log.levels.WARN)
      end

      local new_entries, warn = require("unionbuf.core.entries").new(raw_entries)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
      buffer_entry_maps[bufnr] = require("unionbuf.core.reader").read(bufnr, new_entries)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout" }, {
    buffer = bufnr,
    callback = function()
      buffer_entry_maps[bufnr] = nil
    end,
  })

  opts.open(bufnr)
end

function M.get_entry(raw_opts)
  local opts = require("unionbuf.core.option").new_get_entry_opts(raw_opts)
  local entry_map = buffer_entry_maps[opts.bufnr]
  if not entry_map then
    return nil
  end
  return require("unionbuf.core.reader").get(opts.bufnr, entry_map, opts.row)
end

return M
