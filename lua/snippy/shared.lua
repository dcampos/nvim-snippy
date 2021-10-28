local M = {}

local function get_scopes()
    local scopes = vim.tbl_flatten({ '_', vim.split(vim.bo.filetype, '.', true) })

    if M.config.scopes and M.config.scopes[vim.bo.filetype] then
        local ft_scopes = M.config.scopes[vim.bo.filetype]
        if type(ft_scopes) == 'table' then
            scopes = ft_scopes
        elseif type(ft_scopes) == 'function' then
            scopes = ft_scopes(scopes)
        end
    end

    local buf_config = M.buffer_config[vim.fn.bufnr(0)]
    if buf_config then
        local buf_scopes = buf_config.scopes
        if type(buf_scopes) == 'table' then
            scopes = buf_scopes
        elseif type(buf_scopes) == 'function' then
            scopes = buf_scopes(scopes)
        end
    end

    return scopes
end

local default_config = {
    snippet_dirs = nil,
    hl_group = nil,
    scopes = nil,
    mappings = nil,
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
