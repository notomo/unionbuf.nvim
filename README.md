# unionbuf.nvim

WIP

unionbuf.nvim is a neovim plugin to edit multiple buffers in one buffer.

Inspired by [vim-qfreplace](https://github.com/thinca/vim-qfreplace).

## Example

```lua
require("unionbuf").open({
  {
    path = "path/to/file",
    -- or
    -- bufnr = {buffer number},

    start_row = 0,
    -- end_row = 0,
    -- start_col = 0,
    -- end_col = -1,
  },
  -- ...
})

-- Then, edit the buffer and :write

```