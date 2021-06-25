local M = {}

local function get_scopes()
    return vim.tbl_flatten {'_', vim.split(vim.bo.filetype, '.', true)}
end

local default_config = {
    snippet_dirs = nil,
    hl_group = nil,
    get_scopes = get_scopes
}

M.selected_text = ''
M.namespace = vim.api.nvim_create_namespace('snippy')
M.config = vim.tbl_extend('force', {}, default_config)

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
    M.config = vim.tbl_extend('keep', M.config, params)
end

M.cache = {}

return M
