local M = {}

local function check_visual_mappings()
    local mappings = vim.tbl_filter(function(v)
        return v.mode == 'v'
    end, vim.api.nvim_get_keymap('v'))

    if #mappings > 0 then
        vim.health.warn('Potentially problematic Visual/Select mode mappings detected', {
            "Mappings created with ':vmap' or mode 'v' apply to both Visual and Select modes",
            'This can interfere with snippet expansion in Select mode',
            "Consider using 'x' for Visual-only and 's' for Select-only mappings",
        })
    else
        vim.health.ok('No visual mapping detected')
    end
end

function M.check()
    vim.health.start('snippy')

    check_visual_mappings()
end

return M
