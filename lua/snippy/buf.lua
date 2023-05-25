local shared = require('snippy.shared')

local Stop = require('snippy.stop')

local api = vim.api

local M = {}

M._state = {}

setmetatable(M, {
    __index = function(self, key)
        if key == 'current_stop' then
            return self.state().current_stop
        elseif key == 'stops' then
            return self.state().stops
        else
            return rawget(self, key)
        end
    end,
    __newindex = function(self, key, value)
        if key == 'current_stop' then
            self.state().current_stop = value
        elseif key == 'stops' then
            self.state().stops = value
        else
            return rawset(self, key, value)
        end
    end,
})

--- Add or change an extmark associated with a stop.
---@param id number|nil Extmark identifier (nil for creating a new one)
---@param startrow number
---@param startcol number
---@param endrow number
---@param endcol number
---@param right_gravity number
---@param end_right_gravity number
---@return number Extmark identifier
---@return number? Extmark identifier
local function add_mark(id, startrow, startcol, endrow, endcol, right_gravity, end_right_gravity, end_id, active)
    local config = shared.config
    local opts = {
        id = id,
        end_line = endrow,
        end_col = endcol,
        hl_group = config.hl_group,
        right_gravity = right_gravity,
        end_right_gravity = end_right_gravity,
    }
    if end_id then
        api.nvim_buf_del_extmark(0, shared.namespace, end_id)
        end_id = nil
    end
    if vim.fn.has('nvim-0.10') == 1 and config.virtual_markers.enabled then
        if not active then
            opts.virt_text_pos = 'inline'
            if startrow == endrow and startcol == endcol then
                opts.virt_text = { { config.virtual_markers.empty, config.virtual_markers.hl_group } }
            else
                opts.virt_text = { { config.virtual_markers.start, config.virtual_markers.hl_group } }
                end_id = api.nvim_buf_set_extmark(0, shared.namespace, endrow, endcol, {
                    virt_text_pos = 'inline',
                    virt_text = { { config.virtual_markers['end'], config.virtual_markers.hl_group } },
                    right_gravity = end_right_gravity,
                })
            end
        end
    end
    local mark = api.nvim_buf_set_extmark(0, shared.namespace, startrow, startcol, opts)
    return mark, end_id
end

local function activate_parents(number)
    local parents = M.stops[number]:get_parents()
    for _, n in ipairs(parents) do
        local stop = M.state().stops[n]
        local from, to = stop:get_range()
        local mark_id = stop.mark
        local end_id = stop.end_mark
        local _, end_mark = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true, end_id, true)
        stop.end_mark = end_mark
    end
end

--- Activates a stop (and all its mirrors) by changing its extmark's gravity.
--- Parents (outer stops) must also be activated.
---@param number number Stop number (index)
local function activate_stop_and_parents(number)
    local value = M.state().stops[number]
    for n, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local end_id = stop.end_mark
            local _, end_mark = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true, end_id, true)
            stop.end_mark = end_mark
            activate_parents(n)
        end
    end
end

--- Mirrors a stop and its parents by number.
---@param number number Stop number (index)
function M.mirror_stop(number)
    local stops = M.state().stops
    if number < 1 or number > #stops then
        return
    end
    local cur_stop = stops[number]
    local startpos, _ = cur_stop:get_range()
    if startpos and startpos[1] + 1 > vim.fn.line('$') then
        M.clear_state()
        return
    end
    local text = cur_stop:get_text()
    if cur_stop.prev_text == text then
        return
    end
    cur_stop.prev_text = text
    for i, stop in ipairs(stops) do
        local is_inside = cur_stop:is_inside(stop)
        if not is_inside and i > number and stop.id == cur_stop.id then
            stop:set_text(text)
        end
    end
    if cur_stop.spec.type == 'placeholder' then
        -- cur_stop may not be the actual current active stop
        local real_cur_stop = M.stops[M.current_stop]
        local is_inside = number ~= M.current_stop and real_cur_stop:is_inside(cur_stop)
        if not is_inside and text ~= cur_stop.placeholder then
            M.clear_children(number)
        end
    end
    if cur_stop.spec.parent then
        for i, stop in ipairs(stops) do
            if stop.id == cur_stop.spec.parent then
                M.mirror_stop(i)
            end
        end
    end
end

function M.clear_children(stop_num)
    local current_stop = M.stops[M.current_stop]
    local children = M.stops[stop_num]:get_children()
    table.sort(children)
    for i = #children, 1, -1 do
        table.remove(M.state().stops, children[i])
    end
    -- Reset current stop index
    for i, stop in ipairs(M.state().stops) do
        if stop.id == current_stop.id and #children > 0 then
            M.current_stop = i
            break
        end
    end
end

function M.state()
    local bufnr = api.nvim_buf_get_number(0)
    if not M._state[bufnr] then
        M._state[bufnr] = {
            stops = {},
            current_stop = 0,
            active = false,
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
    local smark, emark = add_mark(nil, startrow, startcol, endrow, endcol, true, true)
    table.insert(
        stops,
        pos,
        Stop.new({ id = spec.id, traversable = is_traversable(), mark = smark, end_mark = emark, spec = spec })
    )
    M.state().stops = stops
end

--- Change the extmark's gravity to allow the tabstop to expand on change.
---@p number number Stop number/index
function M.activate_stop(number)
    activate_stop_and_parents(number)
    local value = M.state().stops[number]
    if value.spec.parent then
        for i, stop in ipairs(M.stops) do
            if stop.id == value.spec.parent then
                activate_stop_and_parents(i)
            end
        end
    end
    if value.spec.type == 'placeholder' then
        value.placeholder = value:get_text()
    end
    M.state().current_stop = number
    M.state().active = true
    M.update_state()
end

--- Change the extmark's gravity to NOT allow the tabstop to expand on change.
function M.deactivate_stops()
    for _, stop in ipairs(M.state().stops) do
        local from, to = stop:get_range()
        local mark_id = stop.mark
        local _, end_id = add_mark(mark_id, from[1], from[2], to[1], to[2], true, true, stop.end_mark, false)
        stop.end_mark = end_id
    end
end

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
        local _, end_mark = add_mark(stop.mark, from[1], #old, to[1], to[2], false, true)
        stop.end_mark = end_mark
    end
end

function M.clear_state()
    if not M.state().active then
        return
    end
    api.nvim_buf_clear_namespace(0, shared.namespace, 0, -1)
    M.state().current_stop = 0
    M.state().stops = {}
    M.state().before = nil
    M.state().active = false
    M.clear_autocmds()
    api.nvim_exec_autocmds('User', { pattern = 'SnippyFinished' })
end

function M.setup_autocmds()
    local autocmd = vim.api.nvim_create_autocmd
    local group = vim.api.nvim_create_augroup('SnippyLocal', {})

    autocmd({ 'TextChanged', 'TextChangedI' }, {
        group = group,
        buffer = 0,
        callback = function()
            require('snippy')._handle_TextChanged()
        end,
    })

    autocmd('TextChangedP', {
        group = group,
        buffer = 0,
        callback = function()
            require('snippy')._handle_TextChangedP()
        end,
    })

    autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group,
        buffer = 0,
        callback = function()
            require('snippy')._handle_CursorMoved()
        end,
    })

    autocmd('BufWritePost', {
        group = group,
        buffer = 0,
        callback = function()
            require('snippy')._handle_BufWritePost()
        end,
    })
end

function M.clear_autocmds()
    pcall(vim.api.nvim_clear_autocmds, { group = 'SnippyLocal', buffer = 0 })
end

return M
