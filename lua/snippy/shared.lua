local M = {}

local function get_scopes()
    return {'_', vim.bo.filetype}
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
    end
    M.selected_text = value
end

function M.set_config(params)
    M.config = vim.tbl_extend('keep', M.config, params)
end

return M
