local helper = require("vusted.helper")
local plugin_name = helper.get_module_root(...)

helper.root = helper.find_plugin_root(plugin_name)

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

function helper.set_lines(bufnr, lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(lines, "\n"))
end

local asserts = require("vusted.assert").asserts
local asserters = require(plugin_name .. ".vendor.assertlib").list()
require(plugin_name .. ".vendor.misclib.test.assert").register(asserts.create, asserters)

asserts.create("lines_after"):register(function(self)
  return function(_, args)
    local before = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    args[1]()
    local after = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

    local diff = vim.diff(after, before, {})
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

return helper
