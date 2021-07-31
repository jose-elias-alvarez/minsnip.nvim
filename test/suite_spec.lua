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

local luasnip = function(snip)
    return function()
        return vim.bo.ft == "lua" and snip
    end
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
        minsnip.setup(snippets)
    end

    before_each(function()
        vim.cmd("e test.lua")
    end)

    after_each(function()
        vim.cmd("bufdo! bdelete!")
    end)

    it("should create namespace", function()
        minsnip.setup({})

        assert.truthy(api.nvim_get_namespaces()["minsnip"])
    end)

    describe("expand", function()
        it("should expand basic snippet", function()
            add_snippets({ print = luasnip("print($0)") })

            expand("print")

            assert_content({ "print()" })
            assert_cursor_at(1, 6)
        end)

        it("should do nothing on non-snippet", function()
            add_snippets({ print = luasnip("print($0)") })

            expand("non")

            assert_content({ "non" })
        end)

        it("should generate and place cursor at end position", function()
            add_snippets({ print = luasnip("print()") })

            expand("print")

            assert_content({ "print()" })
            assert_cursor_at(1, 7)
        end)

        it("should expand multiline snippet", function()
            add_snippets({ func = luasnip([[
            function()
                $0
            end]]) })

            expand("func")

            assert_content({
                "function()",
                "    ",
                "end",
            })
            assert_cursor_at(2, 4)
        end)

        it("should expand snippet within snippet", function()
            add_snippets({ print = luasnip("print($0)") })

            expand("print")
            -- account for insert mode leave
            input("l")
            expand("print")

            assert_content({ "print(print())" })
            assert_cursor_at(1, 12)
        end)

        it("should expand snippet within multiline snippet", function()
            add_snippets({
                bff = luasnip([[
                before_each(function()
                    $0
                end)]]),
                print = luasnip("print($0)"),
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
                bff = luasnip([[
                before_each(function()
                    $0
                end)]]),
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
    end)

    describe("jump", function()
        it("should jump forwards", function()
            add_snippets({ print = luasnip("print($1, $0)") })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should jump backwards", function()
            add_snippets({ print = luasnip("print($1, $2)") })

            expand_and_jump("print", { 1, -1 })

            assert_cursor_at(1, 6)
        end)

        it("should skip over missing position", function()
            add_snippets({ print = luasnip("print($1, $9)") })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should handle double position", function()
            add_snippets({ print = luasnip("print($1, $1)") })

            expand_and_jump("print", { 1 })

            assert_cursor_at(1, 8)
        end)

        it("should handle large number positions", function()
            add_snippets({ print = luasnip("print($111111, $99999999)") })

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
            add_snippets({ print = luasnip(snippet) })

            expand_and_jump("print", jumps)

            assert_cursor_at(1, 107)
        end)

        it("should handle large number of consecutive jumps", function()
            add_snippets({ ins = luasnip("print(vim.inspect($0)") })

            for i = 0, 250 do
                expand("ins")
                assert_cursor_at(i + 1, 18)
                input("i<CR>")
            end
        end)

        it("should jump across multiple lines", function()
            add_snippets({ func = luasnip([[
            function($1)
                $0
            end]]) })

            expand_and_jump("func", { 1 })

            assert_cursor_at(2, 4)
        end)

        it("should jump backwards across multiple lines", function()
            add_snippets({ func = luasnip([[
            function($1)
                $2
            end]]) })

            expand_and_jump("func", { 1, -1 })

            assert_cursor_at(1, 9)
        end)
    end)
end)
