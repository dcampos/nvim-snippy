local shared = require('snippy.shared')
local util = require('snippy.util')

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
            rawset(self, key, value)
        end
    end,
})

--- Add or change an extmark associated with a stop.
---@param id number|nil Extmark identifier (nil for creating a new one)
---@param startrow number
---@param startcol number
---@param endrow number
---@param endcol number
---@param right_gravity boolean
---@param end_right_gravity boolean
---@param opts table?
---@return number Extmark identifier
local function add_mark(id, startrow, startcol, endrow, endcol, right_gravity, end_right_gravity, opts)
    local config = shared.config
    local hl_group = config.hl_group
    opts = vim.tbl_extend('force', {
        id = id,
        end_line = endrow,
        end_col = endcol,
        hl_group = hl_group,
        right_gravity = right_gravity,
        end_right_gravity = end_right_gravity,
    }, opts or {})
    local mark = api.nvim_buf_set_extmark(0, shared.namespace, startrow, startcol, opts)
    return mark
end

--- Creates options for passing to the extmark
---@param stop snippy.Stop
---@param current boolean
---@return table
local function prepare_mark_opts(stop, current)
    local order = stop.order
    local virtual_markers = shared.config.virtual_markers
    local opts = {}
    if vim.fn.has('nvim-0.10') == 1 and virtual_markers.enabled then
        local from, to = stop:get_range()
        if not current and order > 0 then
            opts.virt_text_pos = 'inline'
            if virtual_markers.choice and stop.spec.type == 'choice' then
                -- Choice virtual marker
                local text = util.expand_virtual_marker(virtual_markers.choice, order)
                opts.virt_text = { { text, virtual_markers.hl_group } }
            elseif virtual_markers.empty and from[1] == to[1] and from[2] == to[2] then
                -- Empty virtual marker
                local text = util.expand_virtual_marker(virtual_markers.empty, order)
                opts.virt_text = { { text, virtual_markers.hl_group } }
            else
                -- Default virtual marker
                local text = util.expand_virtual_marker(virtual_markers.default, order)
                opts.virt_text = { { text, virtual_markers.hl_group } }
            end
        end
    end
    return opts
end

local function activate_parents(number, current)
    local parents = M.stops[number]:get_parents()
    for _, n in ipairs(parents) do
        local stop = M.state().stops[n]
        local from, to = stop:get_range()
        local mark_id = stop.mark
        local opts = prepare_mark_opts(stop, current)
        local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true, opts)
    end
end

--- Activates a stop (and all its mirrors) by current its extmark's gravity.
--- Parents (outer stops) must also be activated.
---@param number number Stop number (index)
local function activate_stop_and_parents(number)
    local value = M.state().stops[number]
    for n, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local opts = prepare_mark_opts(stop, n == number)
            local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true, opts)
            activate_parents(n, n == number)
        end
    end
end

--- Gets the ordering number for the next added tabstop.
---@return integer
local function update_order()
    local n = 1
    for _, stop in ipairs(M.state().stops) do
        if stop.traversable then
            stop.order = n
            n = n + 1
        end
    end
    return n
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
    local bufnr = api.nvim_get_current_buf()
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
                assert(spec.is_mirror, vim.inspect(spec))
                return false
            end
        end
        return (spec.type == 'tabstop' or spec.type == 'placeholder' or spec.type == 'choice') and not spec.is_mirror
    end
    local startrow = spec.startpos[1] - 1
    local startcol = spec.startpos[2]
    local endrow = spec.endpos[1] - 1
    local endcol = spec.endpos[2]
    local traversable = is_traversable()
    local smark = add_mark(nil, startrow, startcol, endrow, endcol, true, true)
    local stop = Stop.new({ id = spec.id, order = -1, traversable = traversable, mark = smark, spec = spec })
    table.insert(M.state().stops, pos, stop)
    if traversable then
        update_order()
    end
    local opts = prepare_mark_opts(stop, false)
    -- Update extmark to set virtual markers correctly
    add_mark(smark, startrow, startcol, endrow, endcol, true, true, opts)
end

--- Change the extmark's gravity to allow the tabstop to expand on change.
---@param number number Stop number/index
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
        local opts = prepare_mark_opts(stop, false)
        local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], true, true, opts)
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
        local opts = prepare_mark_opts(stop, true)
        local _ = add_mark(stop.mark, from[1], #old, to[1], to[2], false, true, opts)
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
    M.clear_session_mappings()
    api.nvim_exec_autocmds('User', { pattern = 'SnippyFinished' })
end

function M.setup()
    if not M.state().active then
        return
    end
    M.setup_autocmds()
    M.setup_session_mappings()
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

function M.setup_session_mappings()
    require('snippy.mapping').init(vim.api.nvim_get_current_buf())
end

function M.clear_session_mappings()
    require('snippy.mapping').clear(vim.api.nvim_get_current_buf())
end

function M.clear_autocmds()
    pcall(vim.api.nvim_clear_autocmds, { group = 'SnippyLocal', buffer = 0 })
end

function M.begin_jump()
    M.state().jumping = true
end

function M.end_jump()
    M.state().jumping = false
end

function M.jumping()
    return M.state().jumping == true
end

return M
