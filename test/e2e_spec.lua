local stub = require("luassert.stub")

local api = vim.api

local input = function(keys, mode)
    api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, false, true), mode or "x", true)
end

local assert_cursor_at = function(row, col)
    local cursor = api.nvim_win_get_cursor(0)

    assert.equals(cursor[1], row)
    -- offset to account for feedkeys insert mode leave
    assert.equals(cursor[2], col - 1)
end

local get_lines = function()
    return api.nvim_buf_get_lines(0, 0, -1, false)
end

local assert_content = function(content)
    assert.same(get_lines(), content)
end

describe("e2e", function()
    local minsnip = require("minsnip")
    api.nvim_set_keymap("i", "<Tab>", "<cmd> lua require'minsnip'.jump()<CR>", {})
    api.nvim_set_keymap("i", "<S-Tab>", "<cmd> lua require'minsnip'.jump_backwards()<CR>", {})

    local expand = function(trigger)
        input(string.format("i%s<Tab>", trigger))
    end

    local type = function(text)
        input("i" .. text)
    end

    local jump = function()
        input("i<Tab>")
    end

    local jump_backwards = function()
        input("i<S-Tab>")
    end

    local add_snippets = function(snippets)
        minsnip.setup({ snippets = { lua = snippets } })
    end

    before_each(function()
        vim.cmd("e test.lua")
    end)

    after_each(function()
        vim.cmd("bufdo! bdelete!")
        minsnip.reset()
    end)

    describe("should create namespace", function()
        minsnip.setup({})

        assert.truthy(api.nvim_get_namespaces()["minsnip"])
    end)

    describe("expand", function()
        it("should expand basic snippet", function()
            add_snippets({ print = "print($0)" })

            expand("print")

            assert_content({ "print()" })
            assert_cursor_at(1, 6)
        end)

        it("should do nothing on non-snippet", function()
            add_snippets({ print = "print($0)" })

            expand("non")

            assert_content({ "non" })
        end)

        it("should generate and place cursor at end position", function()
            add_snippets({ print = "print()" })

            expand("print")

            assert_content({ "print()" })
            assert_cursor_at(1, 7)
        end)

        it("should expand multiline snippet", function()
            add_snippets({ func = [[
            function()
                $0
            end]] })

            expand("func")

            assert_content({
                "function()",
                "    ",
                "end",
            })
            assert_cursor_at(2, 4)
        end)

        it("should expand snippet within snippet", function()
            add_snippets({ print = "print($0)" })

            expand("print")
            -- account for insert mode leave
            input("l")
            expand("print")

            assert_content({ "print(print())" })
            assert_cursor_at(1, 12)
        end)

        it("should expand snippet within multiline snippet", function()
            add_snippets({
                bff = [[
            before_each(function()
                $0
            end)]],
                print = "print($0)",
            })

            expand("bff")
            expand("print")

            assert_content({
                "before_each(function()",
                "   print() ",
                "end)",
            })
            assert_cursor_at(2, 9)
        end)

        it("should expand multiline snippet within multiline snippet", function()
            add_snippets({
                bff = [[
            before_each(function()
                $0
            end)]],
            })

            expand("bff")
            expand("bff")

            assert_content({
                "before_each(function()",
                "   before_each(function()",
                "       ",
                "   end) ",
                "end)",
            })
            assert_cursor_at(3, 7)
        end)

        it("should expand table snippet", function()
            add_snippets({
                bff = {
                    "before_each(function()",
                    "    $0",
                    "end)",
                },
            })

            expand("bff")

            assert_content({
                "before_each(function()",
                "    ",
                "end)",
            })
            assert_cursor_at(2, 4)
        end)

        it("should expand function snippet", function()
            add_snippets({
                hello = function()
                    return "Hello!"
                end,
            })

            expand("hello")

            assert_content({ "Hello!" })
        end)

        it("should run callbacks if defined", function()
            local before = stub.new()
            local after = stub.new()
            minsnip.setup({ snippets = { lua = { print = "print($0)" } }, before = before, after = after })

            expand("print")

            assert.stub(before).was_called()
            assert.stub(after).was_called()
        end)
    end)

    describe("jump", function()
        it("should jump forwards", function()
            add_snippets({ print = "print($1, $0)" })
            expand("print")

            jump()

            assert_cursor_at(1, 8)
        end)

        it("should jump backwards", function()
            add_snippets({ print = "print($1, $0)" })
            expand("print")

            jump()
            jump_backwards()

            assert_cursor_at(1, 7)
        end)

        it("should jump forwards, accounting for final position", function()
            add_snippets({ print = "print($1, $2)" })
            expand("print")

            jump()
            assert_cursor_at(1, 8)

            jump()
            assert_cursor_at(1, 9)
        end)

        it("should skip over missing position", function()
            add_snippets({ print = "print($1, $9)" })
            expand("print")

            jump()

            assert_cursor_at(1, 8)
        end)

        it("should handle large number positions", function()
            add_snippets({ print = "print($111111, $99999999)" })
            expand("print")

            jump()

            assert_cursor_at(1, 8)
        end)

        it("should handle large number of positions", function()
            local snippet = "print("
            for i = 0, 100, 1 do
                snippet = snippet .. string.format("$%d ", i)
            end
            add_snippets({ print = snippet })
            expand("print")

            for _ = 0, 100, 1 do
                jump()
            end

            -- original length (6) + 1 space per iteration
            assert_cursor_at(1, 106)
        end)

        it("should jump across multiple lines", function()
            add_snippets({ func = [[
            function($1)
                $0
            end]] })
            expand("func")

            jump()

            assert_cursor_at(2, 4)
        end)

        it("should jump backwards multiple lines", function()
            add_snippets({ func = [[
            function($1)
                $2
            end]] })
            expand("func")

            jump()
            jump_backwards()

            assert_cursor_at(1, 9)
        end)

        it("should jump across multiple lines, accounting for final position", function()
            add_snippets({ func = [[
            function($1)
                $2
            end]] })
            expand("func")

            jump()
            assert_cursor_at(2, 4)

            jump()
            assert_cursor_at(3, 3)
        end)

        it("should offset jump when inserting text", function()
            add_snippets({ print = "print($1, $0)" })
            expand("print")
            type("hello")

            jump()

            assert_cursor_at(1, 13)
        end)

        it("should offset multiple jumps when inserting text", function()
            add_snippets({ print = "print($1, $2, $3)" })
            expand("print")
            type("hello")

            jump()
            type("hello")

            jump()
            assert_cursor_at(1, 20)
        end)

        it("should offset jump when inserting newline", function()
            add_snippets({ print = "print($1, $0)" })
            expand("print")
            type("<CR>")

            jump()

            assert_cursor_at(2, 3)
        end)
    end)

    describe("state", function()
        it("should set buffer info", function()
            add_snippets({ print = "print($1)" })

            expand("print")

            local state = minsnip.inspect().state
            assert.equals(state.bufnr, api.nvim_get_current_buf())
            assert.equals(state.ft, "lua")
            assert.equals(state.trigger, "print")
            assert.equals(state.row, 1)
            assert.equals(state.col, 5)
            assert.equals(state.line, "print")
        end)

        it("should set range based on snippet newlines", function()
            add_snippets({ func = [[
            function($1)
                $2
            end]] })
            expand("func")

            local state = minsnip.inspect().state
            assert.equals(state.range, 3)
        end)

        it("should set one extmark per jump", function()
            add_snippets({ print = "print($1, $2, $0)" })

            expand("print")

            local state = minsnip.inspect().state
            assert.equals(vim.tbl_count(state.extmarks), 3)

            local extmarks = api.nvim_buf_get_extmarks(0, minsnip.inspect().namespace, 0, -1, {})
            assert.equals(vim.tbl_count(extmarks), 3)
        end)

        it("should update jump index on jump", function()
            add_snippets({ print = "print($1, $2)" })

            expand("print")
            assert.equals(minsnip.inspect().state.jump_index, 1)

            jump()
            assert.equals(minsnip.inspect().state.jump_index, 2)
        end)

        it("should set jumping = true when jumping", function()
            add_snippets({ print = "print($1)" })

            expand("print")

            assert.equals(minsnip.inspect().state.jumping, true)
        end)

        it("should reset state after final jump", function()
            add_snippets({ print = "print($1)" })

            expand("print")
            jump()

            local state = minsnip.inspect().state
            assert.equals(state.jumping, false)
            assert.equals(state.jump_index, 0)
            assert.equals(state.bufnr, nil)
            assert.equals(state.ft, nil)
            assert.equals(state.trigger, nil)
            assert.equals(state.row, nil)
            assert.equals(state.col, nil)
            assert.equals(state.line, nil)
            assert.equals(state.range, 0)
            assert.equals(vim.tbl_count(state.extmarks), 0)
        end)

        it("should remove extmarks", function()
            add_snippets({ print = "print($0)" })
            expand("print")

            local extmarks = api.nvim_buf_get_extmarks(0, minsnip.inspect().namespace, 0, -1, {})
            assert.equals(vim.tbl_count(extmarks), 0)
        end)

        it("should stop jumping after attempting invalid jump", function()
            add_snippets({ print = "print($1)" })
            expand("print")

            input("dd")
            jump()

            assert.equals(minsnip.inspect().state.jumping, false)
        end)
    end)

    describe("extends", function()
        it("should get and expand snippet from extended filetype", function()
            minsnip.setup({
                snippets = {
                    typescript = { clg = "console.log($1);" },
                },
                extends = { typescriptreact = { "typescript" } },
            })
            vim.cmd("e test.tsx")

            expand("clg")

            assert_content({ "console.log();" })
            assert_cursor_at(1, 12)
        end)

        it("should add filetype to _parsed", function()
            minsnip.setup({
                snippets = {
                    typescript = { clg = "console.log($1);" },
                },
                extends = { typescriptreact = { "typescript" } },
            })
            vim.cmd("e test.tsx")

            expand("clg")

            assert.same(minsnip.inspect().options._parsed, { "typescriptreact" })
        end)

        it("should do nothing if snippet not found", function()
            minsnip.setup({
                snippets = {
                    typescript = { clg = "console.log($1);" },
                },
                extends = { typescriptreact = { "typescript" } },
            })
            vim.cmd("e test.tsx")

            expand("clq")

            assert_content({ "clq" })
        end)

        it("should do nothing if no extended filetype", function()
            minsnip.setup({
                snippets = {
                    typescript = { clg = "console.log($1);" },
                },
                extends = { teal = { "lua" } },
            })
            vim.cmd("e test.tsx")

            expand("clg")

            assert_content({ "clg" })
        end)
    end)

    describe("autocmd", function()
        it("should create autocmd when jumping", function()
            add_snippets({ print = "print($1)" })

            expand("print")

            assert.equals(vim.fn.exists("#Minsnip#CursorMoved,CursorMovedI"), 1)
        end)

        it("should remove autocmd after jumping", function()
            add_snippets({ print = "print($1)" })

            expand("print")
            jump()

            assert.equals(vim.fn.exists("#Minsnip#CursorMoved,CursorMovedI"), 0)
        end)

        it("should re-ad autocmd on subsequent jump", function()
            add_snippets({ print = "print($1)" })

            expand("print")
            jump()
            expand("print")

            assert.equals(vim.fn.exists("#Minsnip#CursorMoved,CursorMovedI"), 1)
        end)
    end)

    describe("check_pos", function()
        -- annoyingly, the autocmd doesn't seem to trigger in a headless instance,
        -- so we trigger it manually
        it("should keep jumping when moving within range", function()
            add_snippets({ func = [[
            function($1)
                $0
            end]] })
            expand("func")

            vim.cmd("1")
            minsnip.check_pos()

            assert.equals(minsnip.inspect().state.jumping, true)
        end)

        it("should stop jumping when out of range", function()
            add_snippets({ func = [[
            function($1)
                $0
            end]] })
            expand("func")

            vim.cmd("normal 5o")
            minsnip.check_pos()

            assert.equals(minsnip.inspect().state.jumping, false)
        end)
    end)
end)
