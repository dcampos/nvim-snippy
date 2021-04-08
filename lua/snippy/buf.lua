local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

local M = {}

M._state = {}

M.namespace = api.nvim_create_namespace('snippy')

function M.state()
    local bufnr = fn.bufnr('%')
    if not M._state[bufnr] then
        M._state[bufnr] = {
            stops = {};
            current_stop = 0;
        }
    end
    return M._state[bufnr]
end

function M.stops()
    return M.state().stops
end

function M.set_stops(stops)
    M.state().stops = stops
end

function M.current_stop()
    return M.state().current_stop
end

function M.set_current_stop(number)
    M.state().current_stop = number
end

function M.clear_state()
    for _, stop in pairs(M.stops()) do
        api.nvim_buf_del_extmark(0, M.namespace, stop.mark)
    end
    M.set_current_stop(0)
    M.set_stops({})
    M.clear_autocmds()
end

function M.setup_autocmds()
    local bufnr = fn.bufnr('%')
    cmd('augroup snippy_local')
    cmd('autocmd! * <buffer=' .. bufnr ..'>')
    cmd('autocmd TextChanged,TextChangedI,TextChangedP <buffer=' .. bufnr .. '> lua snippy.mirror_stops()')
    cmd('autocmd CursorMoved,CursorMovedI <buffer=' .. bufnr .. '> lua snippy.check_position()')
    cmd('augroup END')
end

function M.clear_autocmds()
    local bufnr = fn.bufnr('%')
    cmd('augroup snippy_local')
    cmd('autocmd! * <buffer=' .. bufnr ..'>')
    cmd('augroup END')
end

return M
