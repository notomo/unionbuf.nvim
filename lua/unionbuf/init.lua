local M = {}

--- @class UnionbufEntry
--- @field start_row integer first line (inclusive, 0-base index)
--- @field start_col integer? first column (inclusive, 0-base index)
--- @field end_row integer? last line (inclusive, 0-base index)
--- @field end_col integer? last column (inclusive, 0-base index)
--- @field bufnr integer? buffer number
--- @field path string? file path

--- @class UnionbufOpenOption
--- @field open fun(bufnr:integer)? open window function using argument buffer number

--- Open unionbuf buffer.
--- Saving buffer applies the changes to entries' original buffers.
---
--- NOTE:
--- - Adjacent line entries are merged.
--- - Entries are grouped by buffer.
--- - Each buffer entries are sorted by start_row ascending.
--- - The buffer can be reloaded.
--- - the entry is removed from the buffer if entry's original text is already changed on save.
---
--- WARNING:
--- - Moving extmark operation like nvim_buf_set_lines() can break entries.
--- @param entries UnionbufEntry[]: |UnionbufEntry|
--- @param opts UnionbufOpenOption?: |UnionbufOpenOption|
function M.open(entries, opts)
  return require("unionbuf.command").open(entries, opts)
end

return M
