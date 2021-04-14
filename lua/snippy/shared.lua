local M = {}

M.selected_text = ''
M.namespace = vim.api.nvim_create_namespace('snippy')

function M.set_selection(value, mode)
    if mode == 'V' or mode == 'line' then
        value = value:sub(1, #value - 1)
    end
    M.selected_text = value
end

return M
