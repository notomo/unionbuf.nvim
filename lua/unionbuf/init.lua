local M = {}

--- @class UnionbufEntryParam
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
--- @param entries UnionbufEntryParam[]: |UnionbufEntryParam|
--- @param opts UnionbufOpenOption?: |UnionbufOpenOption|
function M.open(entries, opts)
  return require("unionbuf.command").open(entries, opts)
end

--- @class UnionbufEntry
--- @field start_row integer first line (inclusive, 0-base index)
--- @field start_col integer first column (inclusive, 0-base index)
--- @field end_row integer last line (inclusive, 0-base index)
--- @field end_col integer last column (inclusive, 0-base index)
--- @field bufnr integer buffer number

--- @class UnionbufGetEntryOption
--- @field bufnr integer? buffer number
--- @field row integer? (inclusive, 0-base index)

--- Returns an entry on the unionbuf buffer.
--- @param opts UnionbufGetEntryOption?: |UnionbufGetEntryOption|
--- @return UnionbufEntry?
function M.get_entry(opts)
  return require("unionbuf.command").get_entry(opts)
end

--- @class UnionbufOffsets
--- @field start_row integer? entry range's start row offest (default: 0)
--- @field end_row integer? entry range's end row offest (default: 0)

--- @class UnionbufShiftOption
--- @field bufnr integer? buffer number
--- @field start_row integer? target range start row in unionbuf buffer (inclusive, 0-base index, default: current cursor row)
--- @field end_row integer? target range end row in unionbuf buffer (inclusive, 0-base index, default: current cursor row)

--- Shifts entries.
--- @param offsets UnionbufOffsets: |UnionbufOffsets|
--- @param opts UnionbufShiftOption?: |UnionbufShiftOption|
function M.shift(offsets, opts)
  require("unionbuf.command").shift(offsets, opts)
end

return M
