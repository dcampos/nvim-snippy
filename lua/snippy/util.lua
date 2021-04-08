-- Util

local api = vim.api
local cmd = vim.cmd

local function print_error(...)
    api.nvim_err_writeln(table.concat(vim.tbl_flatten{...}, ' '))
    cmd 'redraw'
end

local function t(input)
    return api.nvim_replace_termcodes(input, true, false, true)
end

return {
    print_error = print_error,
    t = t,
}
