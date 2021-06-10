local api = vim.api

local namespace = api.nvim_create_namespace("minsnip")

local snippets = {
    lua = {
        clg = "print($1, $2)",
        clip = function()
            return vim.fn.getreg("*")
        end,
    },
}

local initial_state = {
    jump_index = nil,
    bufnr = nil,
    ft = nil,
    cword = nil,
    row = nil,
    col = nil,
    line = nil,
    extmarks = {},
    _dirty = false,
}

setmetatable(initial_state, {
    __newindex = function(tab, key, val)
        if not tab._dirty then
            rawset(tab, "_dirty", true)
        end

        rawset(tab, key, val)
    end,
})

local s = vim.deepcopy(initial_state)

local reset = function()
    if not s._dirty then
        return
    end

    for _, mark in ipairs(s.extmarks) do
        api.nvim_buf_del_extmark(s.bufnr, namespace, mark)
    end

    s = vim.deepcopy(initial_state)
end

local del_text = function(row, start_col, end_col)
    api.nvim_buf_set_text(s.bufnr, row - 1, start_col - 1, row - 1, end_col, {})
end

local add_extmark = function(row, col, pos)
    local mark = api.nvim_buf_set_extmark(s.bufnr, namespace, row - 1, col, {})
    if pos then
        table.insert(s.extmarks, pos, mark)
        return
    end

    table.insert(s.extmarks, mark)
end

local cword = function(cursor, line)
    local word = ""
    for i = cursor[2], 0, -1 do
        local char = string.sub(line, i, i)
        if char:match("%W") then
            break
        end

        word = word .. char
    end

    return string.reverse(word)
end

local init = function()
    reset()

    local cursor = api.nvim_win_get_cursor(0)
    local line = api.nvim_get_current_line()

    s.bufnr = api.nvim_get_current_buf()
    s.ft = vim.bo.ft
    s.cword = cword(cursor, line)
    s.line = line
    s.row = cursor[1]
    s.col = cursor[2]
end

local M = {}
M.reset = reset

local jump = function()
    s.jump_index = s.jump_index or 1

    local mark_pos = api.nvim_buf_get_extmark_by_id(s.bufnr, namespace, s.extmarks[s.jump_index], {})
    api.nvim_win_set_cursor(0, { mark_pos[1] + 1, mark_pos[2] })
    s.jump_index = s.jump_index + 1
end

local can_jump = function()
    return s.extmarks[s.jump_index]
end

local expand = function(snippet)
    local text = type(snippet) == "string" and snippet or snippet()
    if type(text) ~= "string" then
        return
    end

    local split = vim.split(text, "\n")

    local positions, has_final = {}, false
    for split_row, split_text in ipairs(split) do
        for match in string.gmatch(split_text, "%$%d+") do
            if not has_final and match == "$0" then
                has_final = true
            end

            table.insert(positions, { match = match, row = split_row })
        end
    end

    table.sort(positions, function(a, b)
        return a[1] == "$0" and true
            or b == "$0" and false
            or tonumber(string.match(a.match, "%d")) < tonumber(string.match(b.match, "%d"))
    end)

    local trigger_start, trigger_end = string.find(s.line, s.cword)
    if not has_final then
        add_extmark(s.row, trigger_end, vim.tbl_count(positions) + 1)
    end

    api.nvim_buf_set_text(s.bufnr, s.row - 1, s.col, s.row - 1, s.col, split)

    for _, pos in ipairs(positions) do
        local abs_row = s.row + pos.row - 1
        local line = api.nvim_buf_get_lines(s.bufnr, abs_row - 1, abs_row, true)[1]
        local pos_start, pos_end = string.find(line, pos.match)

        add_extmark(abs_row, pos_start)
        del_text(abs_row, pos_start, pos_end)
    end

    del_text(s.row, trigger_start, trigger_end)
    jump()
end

local can_expand = function()
    return snippets[s.ft] and snippets[s.ft][s.cword]
end

M.expand_or_jump = function()
    if can_jump() then
        jump()
        return
    end

    init()

    local snippet = can_expand()
    return snippet and expand(snippet)
end

M.setup = function()
    api.nvim_set_keymap("i", "<C-j>", "<cmd> lua require'minsnip'.expand_or_jump()<CR>", {})
    api.nvim_exec(
        [[
    augroup Minsnip
        autocmd!
        autocmd InsertLeave * lua require'minsnip'.reset()
    augroup END
    ]],
        false
    )
end

return M
