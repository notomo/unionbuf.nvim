local helper = require("unionbuf.test.helper")
local unionbuf = helper.require("unionbuf")

describe("unionbuf.open()", function()
  before_each(helper.before_each)
  after_each(helper.after_each)

  it("opens unionbuf buffer", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr2,
      [[
test2
]]
    )

    local bufnr3 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr3,
      [[
test3_1
test3_2
]]
    )

    local bufnr4 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr4,
      [[
test4_1
test4_2
]]
    )

    local bufnr5 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr5,
      [[
test5_1
test5_2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 0,
        start_col = 2,
      },
      {
        bufnr = bufnr3,
        start_row = 0,
        end_row = 1,
      },
      {
        bufnr = bufnr4,
        start_row = 0,
        end_row = 1,
        end_col = 5,
      },
      {
        bufnr = bufnr5,
        start_row = 1,
        start_col = 2,
        end_col = 5,
      },
    }
    unionbuf.open(entries)

    assert.exists_pattern([[
^test1
st2
test3_1
test3_2
test4_1
test4
st5$]])
  end)

  it("can handle empty entries", function()
    unionbuf.open({})
  end)

  it("groups by buffer and sorts by row", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1_1
test1_2
]]
    )

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr2,
      [[
test2_1
test2_2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
      },
      {
        bufnr = bufnr2,
        start_row = 1,
      },
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    assert.exists_pattern([[
^test1_1
test1_2
test2_1
test2_2
$]])
  end)

  it("merges intersected entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1_1
test1_2
test1_3
test1_4
test1_5
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 0,
        end_row = 1,
      },

      {
        bufnr = bufnr1,
        start_row = 2,
        end_col = 3,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
        start_col = 3,
      },

      {
        bufnr = bufnr1,
        start_row = 3,
        end_row = 4,
        end_col = 3,
      },
      {
        bufnr = bufnr1,
        start_row = 4,
        start_col = 2,
        end_col = 4,
      },
    }
    unionbuf.open(entries)

    assert.exists_pattern([[
^test1_1
test1_2
test1_3
test1_4
test
$]])
  end)

  it("can use path instead of bufnr", function()
    local path = helper.test_data:create_file(
      "test.txt",
      [[
test1
test2
]]
    )

    local entries = {
      {
        path = path,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    assert.exists_pattern([[
^test1$]])
  end)

  it("raises error if buffer is invalid", function()
    local ok, err = pcall(unionbuf.open, {
      {
        bufnr = 8888,
      },
    })
    assert.is_false(ok)
    assert.match("the buffer is invalid", err)
  end)

  it("raises error if row positions are out of range", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test]]
    )

    local ok, err = pcall(unionbuf.open, {
      {
        bufnr = bufnr1,
        start_row = 1,
      },
      {
        bufnr = bufnr1,
        start_row = 0,
        end_row = 1,
      },
    })
    assert.is_false(ok)
    assert.match("start_row = %d is out of range", err)
    assert.match("end_row = %d is out of range", err)
  end)
end)

describe("unionbuf buffer", function()
  before_each(helper.before_each)
  after_each(helper.after_each)

  it("can reload entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    vim.cmd.edit({ bang = true })

    assert.exists_pattern([[^test1$]])
  end)

  it("can edit an entry", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "edited_1")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern("^edited_1$")
    assert.is_false(vim.bo[bufnr1].modified)
  end)

  it("can edit multiple buffer entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr2,
      [[
test2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 0,
        start_col = 2,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "edited_1")
    vim.fn.setline(2, "edited_2")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern("^edited_1$")
    assert.is_false(vim.bo[bufnr1].modified)

    vim.cmd.buffer(bufnr2)
    assert.exists_pattern("^teedited_2$")
    assert.is_false(vim.bo[bufnr2].modified)
  end)

  it("can edit multiple entries in one buffer", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 1,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "edited_1")
    vim.fn.setline(2, "edited_2")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^edited_1
edited_2
$]])
  end)

  it("ignores unmodified entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1_1
test1_2
]]
    )
    local modified1 = false
    vim.api.nvim_buf_attach(bufnr1, false, {
      on_lines = function()
        modified1 = true
      end,
    })

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr2,
      [[
test2
]]
    )
    local modified2 = false
    vim.api.nvim_buf_attach(bufnr2, false, {
      on_lines = function()
        modified2 = true
      end,
    })

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "edited_1")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern("^edited_1$")
    assert.is_true(modified1)
    assert.is_false(vim.bo[bufnr1].modified)

    vim.cmd.buffer(bufnr2)
    assert.exists_pattern("^test2$")
    assert.is_false(modified2)
    assert.is_false(vim.bo[bufnr2].modified)
  end)

  it("does not change buffer if there is no changed entries on write", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 1,
      },
    }
    unionbuf.open(entries)

    assert.lines_after(function()
      vim.cmd.write()
    end)
  end)

  it("can delete entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
test4
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
      },
    }
    unionbuf.open(entries)

    vim.cmd("%delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test2
test4
$]])
  end)

  it("can edit line entry to empty", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^
test2
$]])
  end)

  it("can delete partial entry", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
        start_col = 2,
      },
    }
    unionbuf.open(entries)

    vim.cmd("%delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^te
test2
$]])
  end)

  it("can increase entry lines", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
test4
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
      },
    }
    unionbuf.open(entries)

    vim.api.nvim_buf_set_lines(0, 0, 1, false, { "test2_1", "test2_2" })
    vim.api.nvim_buf_set_lines(0, 2, 3, false, { "test3_1", "test3_2" })

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
test2_1
test2_2
test3_1
test3_2
test4
$]])
  end)

  it("can decrease entry lines", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
test4
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
        end_row = 2,
      },
    }
    unionbuf.open(entries)

    vim.cmd("1delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
test3
test4
$]])
  end)

  it("can delete entry that specfied end_col in end of line", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
        start_col = 0,
        end_col = 5,
      },
    }
    unionbuf.open(entries)

    vim.cmd("1delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
test3
$]])
  end)

  it("can write multiple times", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
      },
    }
    unionbuf.open(entries)
    local union_bufnr = vim.api.nvim_get_current_buf()

    vim.fn.setline(1, "edited_1")
    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.tabedit()
    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
edited_1
test3
$]])

    vim.cmd.buffer(union_bufnr)
    vim.fn.setline(1, "edited_2")
    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
edited_2
test3
$]])
  end)

  it("notifies warning if original buffer has already changed on write", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.api.nvim_buf_set_text(bufnr1, 0, 0, 0, 1, { " " })

    local notified_msg
    local notified_level
    vim.notify = function(msg, level)
      notified_msg = msg
      notified_level = level
    end

    vim.cmd.write()

    assert.matches("already changed", notified_msg)
    assert.equals(vim.log.levels.WARN, notified_level)
  end)

  it("cannot undo right after open", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.cmd.undo({ mods = { silent = true } })

    assert.exists_pattern([[
^test1$]])
  end)

  it("can undo after write", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.fn.setline(1, "edited_1")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.undo({ mods = { silent = true } })

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
$]])
  end)

  it("can undo after deleting all entries", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
      },
    }
    unionbuf.open(entries)

    vim.cmd("%delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.undo({ mods = { silent = true } })

    assert.exists_pattern([[
^test1
test3
$]])
  end)

  it("can undo deleting an entry", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1_1
test1_2
test1_3
]]
    )

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr2,
      [[
test2_1
test2_2
test2_3
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 1,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
      },
    }
    unionbuf.open(entries)

    vim.cmd("3delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1_1
test1_3
$]])

    vim.cmd.undo({ mods = { silent = true } })

    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1_1
test1_3
test2_2
$]])

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1_1
test1_2
test1_3
$]])

    vim.cmd.buffer(bufnr2)
    assert.exists_pattern([[
^test2_1
test2_2
test2_3
$]])
  end)

  it("can undo deleting entries multiple times", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2
test3
test4
test5
]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr1,
        start_row = 2,
      },
      {
        bufnr = bufnr1,
        start_row = 4,
      },
    }
    unionbuf.open(entries)

    vim.cmd("2delete")
    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1
test5
$]])

    helper.break_undo() -- HACK: for testing

    vim.cmd("2delete")
    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1
$]])

    vim.cmd.undo({ mods = { silent = true } })
    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1
test5
$]])

    vim.cmd.undo({ mods = { silent = true } })
    assert.lines_after(function()
      vim.cmd.write()
    end)
    assert.exists_pattern([[
^test1
test3
test5
$]])

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern([[
^test1
test2
test3
test4
test5
$]])
  end)

  it("deletes entries if they are joined", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(bufnr1, [[test1]])

    local bufnr2 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(bufnr2, [[test2]])

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 0,
      },
      {
        bufnr = bufnr2,
        start_row = 0,
      },
    }
    unionbuf.open(entries)

    vim.cmd.join()

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern("^test1 test2$")

    vim.cmd.buffer(bufnr2)
    assert.exists_pattern("^$")
  end)

  it("can delete an entry that is tha last line in original buffer", function()
    local bufnr1 = vim.api.nvim_create_buf(false, true)
    helper.set_lines(
      bufnr1,
      [[
test1
test2]]
    )

    local entries = {
      {
        bufnr = bufnr1,
        start_row = 1,
      },
    }
    unionbuf.open(entries)

    vim.cmd("%delete")

    assert.lines_after(function()
      vim.cmd.write()
    end)

    vim.cmd.buffer(bufnr1)
    assert.exists_pattern("^test1$")
  end)
end)
