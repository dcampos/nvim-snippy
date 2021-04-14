local shared = require 'snippy.shared'

local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

local M = {}

M._state = {}

setmetatable(M, {
    __index = function (self, key)
        if key == "current_stop" then
            return self.state().current_stop
        elseif key == "stops" then
            return self.state().stops
        else
            return rawget(self, key)
        end
    end;
    __newindex = function (self, key, value)
        if key == "current_stop" then
            self.state().current_stop = value
        elseif key == "stops" then
            self.state().stops = value
        else
            return rawset(self, key, value)
        end
    end
})

function M.state()
    local bufnr = api.nvim_buf_get_number(0)
    if not M._state[bufnr] then
        M._state[bufnr] = {
            stops = {};
            current_stop = 0;
        }
    end
    return M._state[bufnr]
end

-- function M.stops()
--     return M.state().stops
-- end

-- function M.set_stops(stops)
--     M.state().stops = stops
-- end

-- function M.current_stop()
--     return M.state().current_stop
-- end

-- function M.set_current_stop(number)
--     M.state().current_stop = number
-- end

function M.clear_state()
    for _, stop in pairs(M.state().stops) do
        api.nvim_buf_del_extmark(0, shared.namespace, stop.mark)
    end
    M.state().current_stop = 0
    M.state().stops = {}
    M.clear_autocmds()
end

function M.setup_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    api.nvim_exec(
        string.format([[
            augroup snippy_local
            autocmd! * <buffer=%s>
            autocmd TextChanged,TextChangedI,TextChangedP <buffer=%s> lua snippy.mirror_stops()
            autocmd CursorMoved,CursorMovedI <buffer=%s> lua snippy.check_position()
            augroup END
        ]], bufnr, bufnr, bufnr),
        false)
end

function M.clear_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    api.nvim_exec(
        string.format([[
            augroup snippy_local
            autocmd! * <buffer=%s>
            augroup END
        ]], bufnr),
        false)
end

return M
