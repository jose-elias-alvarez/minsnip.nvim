local api = vim.api

local input = function(keys)
    api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, false, true), "x", true)
end

local assert_cursor_at = function(row, col)
    local cursor = api.nvim_win_get_cursor(0)

    assert.equals(cursor[1], row)
    assert.equals(cursor[2], col - 1)
end

local get_lines = function()
    return api.nvim_buf_get_lines(0, 0, -1, false)
end

local assert_content = function(content)
    assert.same(get_lines(), content)
end

describe("suite", function()
    local minsnip = require("minsnip")
    api.nvim_set_keymap("i", "<Tab>", "<cmd> lua require'minsnip'.jump()<CR>", {})
    api.nvim_set_keymap("i", "<S-Tab>", "<cmd> lua require'minsnip'.jump_backwards()<CR>", {})

    local expand = function(trigger)
        input(string.format("i%s<Tab>", trigger))
    end

    local expand_and_jump = function(trigger, jumps)
        local cmd = string.format("i%s<Tab>", trigger)
        for _, j in ipairs(jumps) do
            if type(j) == "number" then
                cmd = cmd .. (j == 1 and "<Tab>" or "<S-Tab>")
            else
                cmd = cmd .. j
            end
        end
        input(cmd)
    end

    local add_snippets = function(snippets)
        minsnip.setup({ snippets = { lua = snippets } })
    end

    before_each(function()
        vim.cmd("e test.lua")
    end)

    after_each(function()
        vim.cmd("bufdo! bdelete!")
        minsnip._reset()
    end)

    it("should create namespace", function()
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
    end)

    describe("jump", function()
        it("should jump forwards", function()
            add_snippets({ print = "print($1, $0)" })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should jump backwards", function()
            add_snippets({ print = "print($1, $2)" })

            expand_and_jump("print", { 1, -1 })

            assert_cursor_at(1, 6)
        end)

        it("should skip over missing position", function()
            add_snippets({ print = "print($1, $9)" })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should handle double position", function()
            add_snippets({ print = "print($1, $1)" })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should handle large number positions", function()
            add_snippets({ print = "print($111111, $99999999)" })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should handle large number of positions", function()
            local snippet, jumps = "print(", {}
            for i = 1, 100, 1 do
                snippet = snippet .. string.format("$%d ", i)
                table.insert(jumps, 1)
            end
            snippet = snippet .. ")"
            add_snippets({ print = snippet })

            expand_and_jump("print", jumps)

            assert_cursor_at(1, 107)
        end)

        it("should jump across multiple lines", function()
            add_snippets({ func = [[
            function($1)
                $0
            end]] })

            expand_and_jump("func", { 1 })

            assert_cursor_at(2, 4)
        end)

        it("should jump backwards across multiple lines", function()
            add_snippets({ func = [[
            function($1)
                $2
            end]] })

            expand_and_jump("func", { 1, -1 })

            assert_cursor_at(1, 9)
        end)
    end)

    describe("state", function()
        it("should reset state after expanding", function()
            add_snippets({ print = "print($0)" })

            expand("print")

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

        it("should remove extmarks after expanding", function()
            add_snippets({ print = "print($0)" })
            expand("print")

            local extmarks = api.nvim_buf_get_extmarks(0, minsnip.inspect().namespace, 0, -1, {})
            assert.equals(vim.tbl_count(extmarks), 0)
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
end)
