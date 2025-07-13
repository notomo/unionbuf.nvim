local helper = require("vusted.helper")
local plugin_name = helper.get_module_root(...)

helper.root = helper.find_plugin_root(plugin_name)
vim.opt.packpath:prepend(vim.fs.joinpath(helper.root, "spec/.shared/packages"))
require("assertlib").register(require("vusted.assert").register)

local notify = vim.notify
function helper.before_each()
  helper.test_data = require("unionbuf.vendor.misclib.test.data_dir").setup(helper.root)
  vim.notify = notify
end

function helper.after_each()
  helper.cleanup()
  helper.cleanup_loaded_modules(plugin_name)
  helper.test_data:teardown()
end

function helper.new_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(lines, "\n"))
  return bufnr
end

function helper.break_undo()
  vim.cmd.normal({ bang = true, args = { "i" .. vim.keycode("<C-g>u") } })
end

function helper.undo()
  vim.cmd.undo({ mods = { silent = true } })
end

local asserts = require("vusted.assert").asserts

asserts.create("lines_after_write"):register(function(self)
  return function(_, _)
    local before = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    vim.cmd.write()
    local after = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

    local diff = vim.text.diff(after, before, {})
    self:set_positive(([[diff exists: before(+), after(-)
%s
Before lines:
%s
After lines:
%s]]):format(diff, before, after))
    self:set_negative("diff does not exists")

    return vim.deep_equal(before, after)
  end
end)

function helper.typed_assert(assert)
  local x = require("assertlib").typed(assert)
  ---@cast x +{lines_after_write:fun()}
  return x
end

return helper
