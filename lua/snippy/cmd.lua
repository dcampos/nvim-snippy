local t = require('snippy.util').t

local DEFAULT_SNIPPET = 'snippet ${1:trigger}\n\t${2:$VISUAL}'

local M = {}

local function insert_template(lines)
    if not lines then
        return
    end

    local empty = vim.fn.line('$') == 1 and vim.fn.getline(1) == ''

    if not empty then
        vim.api.nvim_win_set_cursor(0, { vim.fn.line('$'), 0 })
        vim.api.nvim_put({ '' }, 'l', true, true)
    end

    local S = require('snippy.main')
    local snippet = vim.tbl_get(S.snippets, 'snippets', 'snippet') or DEFAULT_SNIPPET
    S.expand_snippet(snippet, '')

    -- Center cursor vertically
    vim.api.nvim_feedkeys(t('<c-o>zz'), 'n', true)
end

function M.edit(params)
    local lines
    if params.range > 0 then
        local line1 = params.line1
        local line2 = params.line2 or line1
        lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
        lines = require('snippy.util').normalize_indent(lines)
        require('snippy.shared').set_selection(lines, 'line')
    end

    if vim.fn.empty(params.args) == 1 then
        local slash = vim.fn.exists('+shellslash') == 1 and '\\' or '/'
        local path = vim.fn.stdpath('config') .. slash .. 'snippets'
        if not (vim.uv or vim.loop).fs_stat(path) then
            vim.fn.mkdir(path, 'p')
        end
        local ft = vim.bo.ft == '' and '_' or vim.bo.ft
        local file = path .. slash .. ft .. '.snippets'
        vim.cmd(params.mods .. [[ split ]] .. vim.fn.fnameescape(file))
    else
        vim.cmd(params.mods .. [[ split ]] .. vim.fn.fnameescape(params.args))
    end

    insert_template(lines)
end

return M
