local setup_highlight_groups = function()
  local highlightlib = require("unionbuf.vendor.misclib.highlight")
  return {
    UnionbufBackgroundOdd = highlightlib.link("UnionbufBackgroundOdd", "Normal"),
    UnionbufBackgroundEven = highlightlib.link("UnionbufBackgroundEven", "NormalFloat"),
  }
end

local group = vim.api.nvim_create_augroup("unionbuf_highlight_group", {})
vim.api.nvim_create_autocmd({ "ColorScheme" }, {
  group = group,
  pattern = { "*" },
  callback = setup_highlight_groups,
})

return setup_highlight_groups()
