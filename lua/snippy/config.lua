local M = {}

local function get_scopes()
    return {'_', vim.bo.filetype}
end

local config = {
    snippet_dirs = nil,
    get_scopes = get_scopes,
}

setmetatable(M, {
    __index = function (self, key)
        if config[key] then
            return config[key]
        else
            return rawget(self, key)
        end
    end;
})

function M.init(params)
    config = vim.tbl_extend('keep', params, config)
end

return M
