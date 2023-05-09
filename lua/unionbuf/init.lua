local M = {}

--- @class UnionbufEntry
--- @field start_row integer first line 0-base index
--- @field start_col integer? first column 0-base index
--- @field end_row integer? last line 0-base index
--- @field end_col integer? last column 0-base index
--- @field bufnr integer? buffer number
--- @field path string? file path

--- @class UnionbufOpenOption
--- @field open fun(bufnr:integer)? open window function using argument buffer number

--- Open unionbuf buffer.
--- @param entries UnionbufEntry[]: |UnionbufEntry|
--- @param opts UnionbufOpenOption?: |UnionbufOpenOption|
function M.open(entries, opts)
  return require("unionbuf.command").open(entries, opts)
end

return M
