local util = require("genvdoc.util")
local plugin_name = vim.env.PLUGIN_NAME
local full_plugin_name = plugin_name .. ".nvim"

local example_path = ("./spec/lua/%s/example.lua"):format(plugin_name)
local example = util.read_all(example_path)

require("genvdoc").generate(full_plugin_name, {
  source = { patterns = { ("lua/%s/init.lua"):format(plugin_name) } },
  chapters = {
    {
      name = function(group)
        return "Lua module: " .. group
      end,
      group = function(node)
        if node.declaration == nil or node.declaration.type ~= "function" then
          return nil
        end
        return node.declaration.module
      end,
    },
    {
      name = "STRUCTURE",
      group = function(node)
        if node.declaration == nil or node.declaration.type ~= "class" then
          return nil
        end
        return "STRUCTURE"
      end,
    },
    {
      name = "HIGHLIGHT GROUPS",
      body = function(ctx)
        local sections = vim
          .iter(util.extract_documented_table("./lua/unionbuf/core/highlight_group.lua"))
          :map(function(hl_group)
            return util.help_tagged(ctx, hl_group.key, "hl-" .. hl_group.key)
              .. util.indent(hl_group.document, 2)
              .. "\n"
          end)
          :totable()
        return vim.trim(table.concat(sections, "\n"))
      end,
    },
    {
      name = "EXAMPLES",
      body = function()
        return util.help_code_block(example)
      end,
    },
  },
})

local gen_readme = function()
  local content = ([[
# %s

unionbuf.nvim is a neovim plugin to edit multiple buffers in one buffer.

Inspired by [vim-qfreplace](https://github.com/thinca/vim-qfreplace).

## Example

```lua
%s
```]]):format(full_plugin_name, example)

  util.write("README.md", content)
end
gen_readme()
