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

function M.setup(o)
    shared.set_config(o)
    require('snippy.mapping').init()
end

function M.setup_buffer(bufnr, o)
    shared.set_buffer_config(bufnr, o)
end

return M
