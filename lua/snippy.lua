local shared = require('snippy.shared')

local M = {}

setmetatable(M, {
    __index = function(_, key)
        if key == 'mapping' then
            return require('snippy.mapping')
        end
        return require('snippy.main')[key]
    end,
})

--- Set configuration
--- @param o snippy.Config Global configuration parameters
function M.setup(o)
    shared.set_config(o)
    require('snippy.mapping').init()
end

--- Set buffer configuration
--- @param bufnr integer Buffer number
--- @param o snippy.BufferConfig Configuration parameters for the current buffer
function M.setup_buffer(bufnr, o)
    shared.set_buffer_config(bufnr, o)
end

return M
