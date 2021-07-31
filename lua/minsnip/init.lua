local api = vim.api

local namespace = api.nvim_create_namespace("minsnip")

local snippets = {}

-- state
local initial_state = {
    jumping = false,
    jump_index = 0,
    bufnr = nil,
    trigger = nil,
    row = nil,
    col = nil,
    line = nil,
    extmarks = {},
}
local s = vim.deepcopy(initial_state)

local augroup = function(autocmd)
    api.nvim_exec(
        string.format(
            [[augroup Minsnip
                autocmd!
                %s
            augroup END]],
            autocmd or ""
        ),
        false
    )
end

local del_text = function(row, start_col, end_col)
    api.nvim_buf_set_text(s.bufnr, row - 1, start_col - 1, row - 1, end_col, {})
end

local make_extmark = function(row, col)
    return api.nvim_buf_set_extmark(s.bufnr, namespace, row - 1, col - 1, {})
end

local resolve_trigger = function(cursor, line)
    local word = ""
    -- iterate backwards from cursor position until non-alphanumeric char is found
    for i = cursor[2], 0, -1 do
        local char = line:sub(i, i)
        if char:match("%W") then
            break
        end

        word = word .. char
    end

    -- reverse to account for backwards iteration
    return word:reverse()
end

local can_jump = function(index)
    return s.jumping and s.extmarks[index or s.jump_index]
end

local reset = function(force)
    if not s.jumping and not force then
        return
    end
    api.nvim_buf_clear_namespace(s.bufnr, namespace, 0, -1)
    augroup(nil)

    s = vim.deepcopy(initial_state)
end

-- main
local function jump(adjustment)
    s.jump_index = s.jump_index + (adjustment or 1)
    if not can_jump() then
        reset()
        return
    end

    local mark_pos = api.nvim_buf_get_extmark_by_id(s.bufnr, namespace, s.extmarks[s.jump_index], {})
    api.nvim_win_set_cursor(0, { mark_pos[1] + 1, mark_pos[2] })

    if not can_jump(s.jump_index + 1) then
        reset()
    end
end

local can_expand = function()
    reset()

    local cursor = api.nvim_win_get_cursor(0)
    local line = api.nvim_get_current_line()

    s.bufnr = api.nvim_get_current_buf()
    s.trigger = resolve_trigger(cursor, line)
    s.line = line
    s.row = cursor[1]
    s.col = cursor[2]

    return snippets[s.trigger]
end

local expand = function(snippet)
    local text = snippet()
    if not text then
        return false
    end

    local split = vim.split(text, "\n")
    local snip_indent = split[1]:match("^%s+")
    local line_indent = s.line:match("^%s+")

    local positions, adjusted, has_final = {}, {}, false
    for split_row, split_text in ipairs(split) do
        for match in split_text:gmatch("%$%d+") do
            if not has_final and match == "$0" then
                has_final = true
            end
            table.insert(positions, { match = match, row = split_row })
        end

        -- adjust to account for [[]] snippet indentation
        if snip_indent then
            local _, indent_end = split_text:find(snip_indent)
            if indent_end then
                split_text = split_text:sub(indent_end + 1)
            end
        end
        -- adjust to account for existing indentation
        if line_indent and split_row > 1 then
            split_text = line_indent .. split_text
        end

        table.insert(adjusted, split_text)
    end

    table.sort(positions, function(a, b)
        -- make sure $0 is always last
        if a.match == "$0" then
            return false
        end
        if b.match == "$0" then
            return true
        end

        return tonumber(a.match:match("%d")) < tonumber(b.match:match("%d"))
    end)

    local trigger_start, trigger_end = s.line:find(s.trigger, s.col - #s.trigger)
    local final = not has_final and make_extmark(s.row, trigger_end + 1)

    api.nvim_buf_set_text(s.bufnr, s.row - 1, s.col, s.row - 1, s.col, adjusted)

    for _, pos in ipairs(positions) do
        local abs_row = s.row + pos.row - 1
        local line = api.nvim_buf_get_lines(s.bufnr, abs_row - 1, abs_row, true)[1]
        local pos_start, pos_end = line:find(pos.match)

        table.insert(s.extmarks, make_extmark(abs_row, pos_start))
        del_text(abs_row, pos_start, pos_end)
    end
    if final then
        table.insert(s.extmarks, final)
    end

    del_text(s.row, trigger_start, trigger_end)

    augroup("autocmd InsertLeave * lua require'minsnip'.reset()")
    s.jumping = true
    jump()

    return true
end

-- exports
local M = {}

M.jump = function()
    if can_jump() then
        jump()
        return true
    end

    local snippet = can_expand()
    if snippet then
        return expand(snippet)
    end

    return false
end

M.jump_backwards = function()
    jump(-1)
end

M.setup = function(user_snippets)
    snippets = user_snippets
end

M.reset = reset
local snippets = {
    -- global snippet
    clip = function()
        return vim.fn.getreg("*")
    end,
    -- filetype-specific snippet
    print = function()
        return vim.bo.ft == "lua" and "print($1)"
    end,
    -- bracket strings work, too
    func = function()
        return vim.bo.ft == "lua" and [[
    function($1)
        $0
    end]]
    end,
}

return M
