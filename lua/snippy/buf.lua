local shared = require 'snippy.shared'

local Stop = require 'snippy.stop'

local api = vim.api
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

local function add_mark(id, startrow, startcol, endrow, endcol, right_gravity, end_right_gravity)
    local mark = api.nvim_buf_set_extmark(0, shared.namespace, startrow, startcol, {
        id = id;
        end_line = endrow;
        end_col = endcol;
        hl_group = shared.config.hl_group;
        right_gravity = right_gravity;
        end_right_gravity = end_right_gravity;
    })
    return mark
end

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

function M.add_stop(spec, pos)
    local function is_traversable()
        for _, stop in ipairs(M.state().stops) do
            if stop.id == spec.id then
                return false
            end
        end
        return spec.type == 'tabstop' or spec.type == 'placeholder' or spec.type == 'choice'
    end
    local startrow = spec.startpos[1] - 1
    local startcol = spec.startpos[2]
    local endrow = spec.endpos[1] - 1
    local endcol = spec.endpos[2]
    local stops = M.state().stops
    local smark = add_mark(nil, startrow, startcol, endrow, endcol, true, true)
    table.insert(stops, pos, Stop.new({id=spec.id, traversable=is_traversable(), mark=smark, spec=spec}))
    M.state().stops = stops
end

-- Change the extmarks to expand on change
function M.activate_stop(number)
    local value = M.state().stops[number]
    for _, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true)
        end
    end
    M.state().current_stop = number
    M.update_state()
end

-- Change the extmarks NOT to expand on change
function M.deactivate_stop(number)
    local value = M.state().stops[number]
    for _, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], true, true)
        end
    end
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

function M.update_state()
    local current_stop = M.stops[M.current_stop]
    if not current_stop then
        return
    end
    local before = current_stop:get_before()
    M.state().before = before
end

function M.fix_current_stop()
    local current_stop = M.stops[M.current_stop]
    if not current_stop then
        return
    end
    local new = current_stop:get_before()
    local old = M.state().before or new
    local current_line = api.nvim_get_current_line()
    if new ~= old and current_line:sub(1, #old) == old then
        local stop = M.stops[M.current_stop]
        local from, to = stop:get_range()
        add_mark(stop.mark, from[1], #old, to[1], to[2], false, true)
    end
end

function M.clear_state()
    for _, stop in pairs(M.state().stops) do
        api.nvim_buf_del_extmark(0, shared.namespace, stop.mark)
    end
    M.state().current_stop = 0
    M.state().stops = {}
    M.state().before = nil
    M.clear_autocmds()
end

function M.setup_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    cmd(
        string.format([[
            augroup snippy_local
            autocmd! * <buffer=%s>
            autocmd TextChanged,TextChangedI <buffer=%s> lua require 'snippy'._handle_TextChanged()
            autocmd TextChangedP <buffer=%s> lua require 'snippy'._handle_TextChangedP()
            autocmd CursorMoved,CursorMovedI <buffer=%s> lua require 'snippy'._handle_CursorMoved()
            augroup END
        ]], bufnr, bufnr, bufnr, bufnr))
end

function M.clear_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    cmd(
        string.format([[
            augroup snippy_local
            autocmd! * <buffer=%s>
            augroup END
        ]], bufnr))
end

return M
