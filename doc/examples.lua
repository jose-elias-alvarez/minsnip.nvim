-- define utils for common operations
-- get current buffer's filename minus path and extension
local fname = function()
    return vim.fn.expand("%:t:r")
end

-- get clipboard contents
local clipboard = function()
    return vim.fn.getreg("*")
end

-- filetype helpers
-- wrap snippets for specific filetypes
local lua = function(snip)
    return vim.bo.ft == "lua" and snip
end

local typescript = function(snip)
    return vim.bo.ft == "typescript" and snip
end

-- wrap strings with functions for convenience
local lua_string = function(str)
    return vim.bo.ft == "lua" and function()
        return str
    end
end

return {
    -- simple snippet for multiple filetypes
    log = function()
        return lua("print(vim.inspect($0))") or typescript("console.log($0);")
    end,

    -- single-filetype snippet using string helper
    imp = lua_string('local $1 = require("$0")'),

    -- multiline snippet (leading whitespace is trimmed up to first line's indentation)
    dsc = function()
        return lua([[
        describe("$1", function()
            $0
        end)]]) or typescript([[
        describe("$1", () => {
            $0
        });]])
    end,

    -- log variable from clipboard
    logc = function()
        local cb = vim.trim(clipboard())
        return lua(string.format('print("%s", %s)', cb, cb))
    end,

    -- create describe block for current spec file
    testfile = function()
        return lua(string.format(
            [[
            describe("%s", function()
                $0
            end)]],
            fname():gsub("%_spec", "")
        ))
    end,
}
