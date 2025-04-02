local M = {}

local function get_scopes()
    local scopes = { '_' }
    if vim.bo.filetype ~= '' then
        vim.list_extend(scopes, vim.split(vim.bo.filetype, '.', true))
    end

    -- Check for global config
    if M.config.scopes['_'] then
        local global_scopes = M.config.scopes['_']
        scopes = type(global_scopes) == 'table' and global_scopes or global_scopes(scopes)
    end

    -- Check for filetype-specific config (overrides global)
    if M.config.scopes and M.config.scopes[vim.bo.filetype] then
        local ft_scopes = M.config.scopes[vim.bo.filetype]
        scopes = type(ft_scopes) == 'table' and ft_scopes or ft_scopes(scopes)
    end

    -- Check for buffer-specific config (overrides filetype-specific)
    local buf_config = M.buffer_config[vim.fn.bufnr(0)]
    if buf_config then
        local buf_scopes = buf_config.scopes
        scopes = type(buf_scopes) == 'table' and buf_scopes or buf_scopes(scopes)
    end

    return scopes
end

---@class snippy.Config
local default_config = {
    ---@type string|table
    snippet_dirs = nil,
    ---@type string
    local_snippet_dir = '.snippets',
    ---@type string
    hl_group = 'SnippyPlaceholder',
    ---@type table|function
    scopes = {},
    ---@type table
    mappings = {},
    ---@type integer?
    choice_delay = 100,
    ---@type boolean
    enable_auto = false,
    ---@type table
    expand_options = {},
    ---@type table
    logging = {
        enabled = false,
        level = 'debug',
    },
    ---@type table
    virtual_markers = {
        enabled = false,
        empty = '',
        default = '',
        hl_group = 'SnippyMarker',
    },
}

---@class snippy.BufferConfig
---@field scopes table|function List of scopes for the current buffer.
M.buffer_config = {}

M.get_scopes = get_scopes
M.selected_text = nil
M.namespace = vim.api.nvim_create_namespace('snippy')
M.config = vim.tbl_extend('force', {}, default_config)
M.enable_auto = false
M.last_char = ''

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
    vim.api.nvim_exec_autocmds('User', { pattern = 'SnippyTextCut' })
end

function M.set_config(params)
    if vim.fn.has('nvim-0.11') == 1 then
        vim.validate('params', params, 'table')
    else
        vim.validate({
            params = { params, 't' },
        })
    end
    if params.snippet_dirs then
        local dirs = params.snippet_dirs
        local dir_list = type(dirs) == 'table' and dirs or vim.split(dirs, ',')
        for _, dir in ipairs(dir_list) do
            if vim.fn.isdirectory(vim.fn.expand(dir) .. '/snippets') == 1 then
                vim.notify(
                    'Snippy: folders in "snippet_dirs" should no longer contain a "snippets" subfolder',
                    vim.log.levels.WARN
                )
            end
        end
        params.snippet_dirs = dir_list
    end
    if params.enable_auto then
        local group = vim.api.nvim_create_augroup('SnippyAuto', {})
        local autocmd = vim.api.nvim_create_autocmd

        autocmd({ 'TextChangedI', 'TextChangedP' }, {
            group = group,
            pattern = '*',
            callback = function()
                require('snippy').expand(true)
            end,
        })

        autocmd('InsertCharPre', {
            group = group,
            pattern = '*',
            callback = function()
                M.last_char = vim.v.char
            end,
        })
    end
    if params.logging then
        params.logging = vim.tbl_extend('keep', params.logging, M.config.logging)
    end
    if params.virtual_markers then
        params.virtual_markers = vim.tbl_extend('keep', params.virtual_markers, M.config.virtual_markers)
    end
    M.config = vim.tbl_extend('force', M.config, params)
end

function M.set_buffer_config(bufnr, params)
    if vim.fn.has('nvim-0.11') == 1 then
        vim.validate('bufnr', bufnr, 'number')
        vim.validate('params', params, 'table')
    else
        vim.validate({
            bufnr = { bufnr, 'n' },
            params = { params, 't' },
        })
    end
    M.buffer_config[vim.fn.bufnr(bufnr)] = params
end

M.cache = {}

return M
