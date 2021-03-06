local api = vim.api

local trigger_regex = vim.regex("\\k*$")
local namespace = api.nvim_create_namespace("minsnip")
local snippets = {}

-- utils
local del_text = function(bufnr, row, start_col, end_col)
    api.nvim_buf_set_text(bufnr, row - 1, start_col - 1, row - 1, end_col, {})
end

local make_extmark = function(bufnr, row, col)
    return api.nvim_buf_set_extmark(bufnr, namespace, row - 1, col - 1, {})
end

local resolve_trigger = function(col, line)
    return line:sub(trigger_regex:match_str(line:sub(1, col)) + 1, col)
end

local has_final = function(positions)
    for _, pos in ipairs(positions) do
        if pos.index == 0 then
            return true
        end
    end
    return false
end

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

local can_jump = function(index)
    return s.jumping and s.extmarks[index or s.jump_index]
end

local reset = function(force)
    if not s.jumping and not force then
        return
    end
    api.nvim_buf_clear_namespace(s.bufnr, namespace, 0, -1)

    s = vim.deepcopy(initial_state)
end

local initialize_state = function()
    reset()

    local row, col = unpack(api.nvim_win_get_cursor(0))
    local line = api.nvim_get_current_line()

    s.bufnr = api.nvim_get_current_buf()
    s.trigger = resolve_trigger(col, line)
    s.line = line
    s.row = row
    s.col = col
end

-- main
local function jump(adjustment)
    s.jump_index = s.jump_index + (adjustment or 1)
    if not can_jump() then
        reset()
        return false
    end

    local mark_pos = api.nvim_buf_get_extmark_by_id(s.bufnr, namespace, s.extmarks[s.jump_index], {})
    vim.schedule(function()
        api.nvim_win_set_cursor(0, { mark_pos[1] + 1, mark_pos[2] })
        if not can_jump(s.jump_index + 1) then
            reset()
        end
    end)

    return true
end

local can_expand = function(trigger)
    initialize_state()
    return snippets[trigger or s.trigger]
end

local expand = function(snippet)
    local text = snippet()
    if not text then
        return false
    end

    local split = vim.split(text, "\n")
    local snip_indent = split[1]:match("^%s+")
    local line_indent = s.line:match("^%s+")

    local positions, adjusted = {}, {}
    for split_row, split_text in ipairs(split) do
        for match in split_text:gmatch("%$%d+") do
            table.insert(positions, {
                match = match,
                row = split_row,
                index = tonumber(match:match("%d+")),
            })
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
        -- make sure 0 is always last
        if a.index == 0 then
            return false
        end
        if b.index == 0 then
            return true
        end

        return a.index < b.index
    end)

    local trigger_start, trigger_end = s.line:find(s.trigger, s.col - #s.trigger)
    local final = not has_final(positions) and make_extmark(s.bufnr, s.row, trigger_end + 1)

    api.nvim_buf_set_text(s.bufnr, s.row - 1, s.col, s.row - 1, s.col, adjusted)

    for _, pos in ipairs(positions) do
        local abs_row = s.row + pos.row - 1
        local line = api.nvim_buf_get_lines(s.bufnr, abs_row - 1, abs_row, true)[1]
        local pos_start, pos_end = line:find(pos.match)

        table.insert(s.extmarks, make_extmark(s.bufnr, abs_row, pos_start))
        del_text(s.bufnr, abs_row, pos_start, pos_end)
    end

    if final then
        table.insert(s.extmarks, final)
    end

    del_text(s.bufnr, s.row, trigger_start, trigger_end)

    vim.cmd("autocmd InsertLeave * ++once lua require'minsnip'.reset()")
    s.jumping = true
    jump()

    return true
end

-- exports
local M = {}

M.snippets = snippets

M.reset_snippets = function()
    snippets = {}
end

M.jump = function()
    if can_jump() then
        return jump()
    end

    local snippet = can_expand()
    if snippet then
        return expand(snippet)
    end

    return false
end

M.jump_backwards = function()
    return can_jump(s.jump_index - 1) and jump(-1)
end

M.setup = function(user_snippets)
    for k, v in pairs(user_snippets) do
        snippets[k] = v
    end
end

M.reset = reset

return M
