local setup_highlight_groups = function()
  local highlightlib = require("unionbuf.vendor.misclib.highlight")
  return {
    --used for background on odd line
    UnionbufBackgroundOdd = highlightlib.link("UnionbufBackgroundOdd", "Normal"),
    --used for background on even line
    UnionbufBackgroundEven = highlightlib.link("UnionbufBackgroundEven", "NormalFloat"),
    --used for text to show no entries
    UnionbufNoEntries = highlightlib.link("UnionbufNoEntries", "Comment"),
  }
end

local group = vim.api.nvim_create_augroup("unionbuf_highlight_group", {})
vim.api.nvim_create_autocmd({ "ColorScheme" }, {
  group = group,
  pattern = { "*" },
  callback = function()
    setup_highlight_groups()
  end,
})

return setup_highlight_groups()
