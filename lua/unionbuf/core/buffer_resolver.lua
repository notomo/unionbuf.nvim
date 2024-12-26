local M = {}

function M.resolve(raw_entries)
  local keys = {}
  vim.iter(raw_entries):each(function(raw_entry)
    if raw_entry.bufnr then
      keys[raw_entry.bufnr] = false
      return
    end
    keys[raw_entry.path] = true
  end)

  local path_to_bufnr = {}
  local bufnr_to_info = {}
  local errs = {}
  vim.iter(vim.tbl_keys(keys)):each(function(key)
    local bufnr
    if keys[key] then
      bufnr = vim.fn.bufadd(key)
      vim.fn.bufload(bufnr)
      path_to_bufnr[key] = bufnr
    else
      bufnr = key
    end

    if bufnr_to_info[bufnr] then
      return
    end

    local info = M._resolve_bufnr(bufnr)
    if type(info) == "string" then
      local err = info
      table.insert(errs, err)
      return
    end
    bufnr_to_info[bufnr] = info
  end)

  if #errs > 0 then
    return "[unionbuf] Invalid entries:\n" .. table.concat(errs, "\n")
  end
  return {
    path_to_bufnr = path_to_bufnr,
    bufnr_to_info = bufnr_to_info,
  }
end

function M._resolve_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ("- Buffer=%d : the buffer is invalid"):format(bufnr)
  end

  if vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].modified and vim.bo[bufnr].buflisted then
    -- to sync buffer with file
    vim.cmd.checktime(bufnr)
  end

  return {
    max_row = vim.api.nvim_buf_line_count(bufnr) - 1,
  }
end

return M
