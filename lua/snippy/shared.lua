local M = {}

local function get_scopes()
    local scopes = vim.tbl_flatten({ '_', vim.split(vim.bo.filetype, '.', true) })

    if M.config.scopes['_'] then
        local global_scopes = M.config.scopes['_']
        scopes = type(global_scopes) == 'table' and global_scopes or global_scopes(scopes)
    end

    if M.config.scopes and M.config.scopes[vim.bo.filetype] then
        local ft_scopes = M.config.scopes[vim.bo.filetype]
        scopes = type(ft_scopes) == 'table' and ft_scopes or ft_scopes(scopes)
    end

    local buf_config = M.buffer_config[vim.fn.bufnr(0)]
    if buf_config then
        local buf_scopes = buf_config.scopes
        scopes = type(buf_scopes) == 'table' and buf_scopes or buf_scopes(scopes)
    end

    return scopes
end

local default_config = {
    snippet_dirs = nil,
    hl_group = nil,
    scopes = {},
    mappings = {},
    choice_delay = 100,
}

M.get_scopes = get_scopes
M.selected_text = ''
M.namespace = vim.api.nvim_create_namespace('snippy')
M.config = vim.tbl_extend('force', {}, default_config)
M.buffer_config = {}

function M.set_selection(value, mode)
    if mode == 'V' or mode == 'line' then
        value = value:sub(1, #value - 1)
        local lines = vim.split(value, '\n')
        local indent = ''
        for i, line in ipairs(lines) do
            if i == 1 then
                indent = line:match('^%s*')
            end
            lines[i] = line:gsub('^' .. indent, '')
        end
        value = table.concat(lines, '\n')
    end
    M.selected_text = value
end

function M.set_config(params)
    vim.validate({
        params = { params, 't' },
    })
    if params.snippet_dirs then
        local dirs = params.snippet_dirs
        local dir_list = type(dirs) == 'table' and dirs or vim.split(dirs, ',')
        for _, dir in ipairs(dir_list) do
            if vim.fn.isdirectory(vim.fn.expand(dir) .. '/snippets') == 1 then
                vim.api.nvim_echo({
                    {
                        'Snippy: folders in "snippet_dirs" should no longer contain a "snippets" subfolder',
                        'WarningMsg',
                    },
                }, true, {})
            end
        end
    end
    M.config = vim.tbl_extend('force', M.config, params)
end

function M.set_buffer_config(bufnr, params)
    vim.validate({
        bufnr = { bufnr, 'n' },
        params = { params, 't' },
    })
    M.buffer_config[vim.fn.bufnr(bufnr)] = params
end

M.cache = {}

return M
