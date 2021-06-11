local api = vim.api

local namespace = api.nvim_create_namespace("minsnip")

local initial_state = {
    jump_index = nil,
    bufnr = nil,
    ft = nil,
    trigger = nil,
    row = nil,
    col = nil,
    line = nil,
    range = 0,
    extmarks = {},
}

local snippets = {}

local s = vim.deepcopy(initial_state)

local M = {}

local reset = function()
    if not s.jump_index then
        return
    end

    api.nvim_buf_clear_namespace(s.bufnr, namespace, s.row, s.row + s.range)
    api.nvim_exec([[
        augroup Minsnip
            autocmd!
        augroup END
        ]], false)

    s = vim.deepcopy(initial_state)
end

M.reset = reset

local del_text = function(row, start_col, end_col)
    api.nvim_buf_set_text(s.bufnr, row - 1, start_col - 1, row - 1, end_col, {})
end

local make_extmark = function(row, col)
    return api.nvim_buf_set_extmark(s.bufnr, namespace, row - 1, col, {})
end

local resolve_trigger = function(cursor, line)
    local word = ""
    for i = cursor[2], 0, -1 do
        local char = line:sub(i, i)
        if char:match("%W") then
            break
        end

        word = word .. char
    end

    return word:reverse()
end

local init = function()
    reset()

    local cursor = api.nvim_win_get_cursor(0)
    local line = api.nvim_get_current_line()

    s.bufnr = api.nvim_get_current_buf()
    s.ft = vim.bo.ft
    s.trigger = resolve_trigger(cursor, line)
    s.line = line
    s.row = cursor[1]
    s.col = cursor[2]
end

M.check_pos = function()
    if not s.jump_index then
        return
    end

    local row = api.nvim_win_get_cursor(0)[1]
    if math.abs(row - s.row) >= s.range then
        reset()
    end
end

local can_jump = function()
    return s.extmarks[s.jump_index]
end

local jump = function(adjustment)
    s.jump_index = (s.jump_index or 0) + (adjustment or 1)
    if not can_jump() then
        return M.expand_or_jump()
    end

    local mark_pos = api.nvim_buf_get_extmark_by_id(s.bufnr, namespace, s.extmarks[s.jump_index], {})
    local ok = pcall(api.nvim_win_set_cursor, 0, { mark_pos[1] + 1, mark_pos[2] })
    if not ok then
        return reset()
    end
end

M.jump = jump

local expand = function(snippet)
    api.nvim_exec(
        [[
    augroup Minsnip
        autocmd!
        autocmd CursorMoved,CursorMovedI * lua require'minsnip'.check_pos()
    augroup END
    ]],
        false
    )

    local text = type(snippet) == "function" and snippet() or snippet
    local split = type(text) == "string" and vim.split(text, "\n") or text
    local snip_indent = split[1]:match("^%s+")
    local line_indent = s.line:match("^%s+")

    local positions, adjusted = {}, {}
    for split_row, split_text in ipairs(split) do
        s.range = s.range + 1
        for match in split_text:gmatch("%$%d+") do
            table.insert(positions, { match = match, row = split_row })
        end

        if snip_indent then
            local _, indent_end = split_text:find(snip_indent)
            if indent_end then
                split_text = split_text:sub(indent_end + 1)
            end
        end
        if line_indent and split_row > 1 then
            split_text = line_indent .. split_text
        end
        table.insert(adjusted, split_text)
    end

    table.sort(positions, function(a, b)
        if a.match == "$0" then
            return false
        end
        if b.match == "$0" then
            return true
        end

        return tonumber(a.match:match("%d")) < tonumber(b.match:match("%d"))
    end)

    api.nvim_buf_set_text(s.bufnr, s.row - 1, s.col, s.row - 1, s.col, adjusted)

    for _, pos in ipairs(positions) do
        local abs_row = s.row + pos.row - 1
        local line = api.nvim_buf_get_lines(s.bufnr, abs_row - 1, abs_row, true)[1]
        local pos_start, pos_end = line:find(pos.match)

        table.insert(s.extmarks, make_extmark(abs_row, pos_start))
        del_text(abs_row, pos_start, pos_end)
    end

    local trigger_start, trigger_end = s.line:find(s.trigger, s.col - #s.trigger)
    del_text(s.row, trigger_start, trigger_end)

    jump()
end

local can_expand = function()
    init()
    return snippets[s.ft] and snippets[s.ft][s.trigger]
end

M.expand_or_jump = function()
    if can_jump() then
        return jump()
    end

    local snippet = can_expand()
    if snippet then
        expand(snippet)
    end
end

M.can_expand_or_jump = function()
    return can_jump() or can_expand()
end

M.setup = function(user_opts)
    snippets = user_opts.snippets
end

return M
