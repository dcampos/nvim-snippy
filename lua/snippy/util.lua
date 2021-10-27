-- Util

local api = vim.api
local cmd = vim.cmd

local function print_error(...)
    api.nvim_err_writeln(table.concat(vim.tbl_flatten({ ... }), ' '))
    cmd('redraw')
end

local function is_after(pos1, pos2)
    return pos1[1] > pos2[1] or (pos1[1] == pos2[1] and pos1[2] > pos2[2])
end

local function is_before(pos1, pos2)
    return pos1[1] < pos2[1] or (pos1[1] == pos2[1] and pos1[2] < pos2[2])
end

local function t(input)
    return api.nvim_replace_termcodes(input, true, false, true)
end

return {
    print_error = print_error,
    is_after = is_after,
    is_before = is_before,
    t = t,
}
