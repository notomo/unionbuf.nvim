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
