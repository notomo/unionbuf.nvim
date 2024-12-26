local M = {}

local buffer_raw_entries = {}
local buffer_entry_maps = {}

function M.open(raw_entries, raw_opts)
  local opts = require("unionbuf.core.option").new_open_opts(raw_opts)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "unionbuf"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "unionbuf://" .. tostring(bufnr))
  buffer_raw_entries[bufnr] = raw_entries

  local err = M._read(bufnr)
  if err then
    error(err)
  end

  vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
    buffer = bufnr,
    nested = true,
    callback = function()
      local warn = M._read(bufnr)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
    buffer = bufnr,
    nested = true,
    callback = function()
      local entry_map = buffer_entry_maps[bufnr]
      local new_raw_entries, write_warn = require("unionbuf.core.writer").write(bufnr, entry_map)
      buffer_raw_entries[bufnr] = new_raw_entries
      if write_warn then
        vim.notify(write_warn, vim.log.levels.WARN)
      end

      local warn = M._read(bufnr)
      if warn then
        vim.notify(warn, vim.log.levels.WARN)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout" }, {
    buffer = bufnr,
    callback = function()
      buffer_raw_entries[bufnr] = nil
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

local default_offsets = {
  start_row = 0,
  end_row = 0,
}
function M.shift(raw_offsets, raw_opts)
  local offsets = vim.tbl_deep_extend("force", default_offsets, raw_offsets)
  local opts = require("unionbuf.core.option").new_shift_opts(raw_opts)

  local bufnr = opts.bufnr
  local entry_map = buffer_entry_maps[bufnr]
  if not entry_map then
    error("not found entries in buffer=" .. tostring(bufnr))
  end

  local raw_entries = require("unionbuf.core.reader").shift(bufnr, entry_map, opts.start_row, opts.end_row, offsets)
  buffer_raw_entries[bufnr] = raw_entries

  local err = M._read(bufnr)
  if err then
    error(err)
  end
end

function M._read(bufnr)
  local entries = require("unionbuf.core.entries").new(buffer_raw_entries[bufnr])
  if type(entries) == "string" then
    local err = entries
    return err
  end
  buffer_entry_maps[bufnr] = require("unionbuf.core.reader").read(bufnr, entries)
end

return M
