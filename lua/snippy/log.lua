local config = require('snippy.shared').config

local dummy = setmetatable({}, {
    __index = function(_, _)
        return function() end
    end,
})

local logger = dummy

if config.logging.enabled then
    local ok, plog = pcall(require, 'plenary.log')
    if ok then
        logger = plog.new({
            plugin = 'snippy',
            level = config.logging.level or 'debug',
        })
    end
end

return logger
