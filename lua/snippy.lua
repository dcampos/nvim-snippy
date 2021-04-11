local parser = require 'snippy.parser'
local reader = require 'snippy.reader'
local buf = require 'snippy.buf'
local config = require 'snippy.config'

local Builder = require 'snippy.builder'
local Stop = require 'snippy.stop'

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local M = {}

-- Util

local function print_error(...)
    api.nvim_err_writeln(table.concat(vim.tbl_flatten{...}, ' '))
    cmd 'redraw'
end

local function t(input)
    return api.nvim_replace_termcodes(input, true, false, true)
end

-- Stop management

local function add_stop(spec, pos)
    local function is_traversable()
        for _, stop in ipairs(buf.stops) do
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
    local stops = buf.stops
    local end_col = endcol
    local smark = api.nvim_buf_set_extmark(0, buf.namespace, startrow, startcol, {
        end_line = endrow;
        end_col = end_col;
        hl_group = 'Search';
        right_gravity = false;
        end_right_gravity = true;
    })
    table.insert(stops, pos, Stop.new({id=spec.id, traversable=is_traversable(), mark=smark, spec=spec}))
    buf.stops = stops
end

local function select_stop(from, to)
    fn.setpos("'<", {0, from[1] + 1, from[2] + 1})
    fn.setpos("'>", {0, to[1] + 1, to[2]})
    if fn.mode() ~= 's' then
        api.nvim_feedkeys(t'gv<C-g>', 'ntx', true)
    end
end

local function start_insert(pos)
    pos[1] = pos[1] + 1
    pos[2] = pos[2] + 1
    fn.setpos(".", {0, pos[1], pos[2]})
    if pos[2] >= fn.col('$') then
        cmd 'startinsert!'
    else
        cmd 'startinsert'
    end
end

local function make_completion_choices(choices)
    local items = {}
    for _, value in ipairs(choices) do
        table.insert(items, {
            word = value,
            abbr = value,
            menu = '[snip]',
            kind = 'Choice'
        })
    end
    return items
end

local function present_choices(stop, startpos)
    local timer = vim.loop.new_timer()
    timer:start(500, 0, vim.schedule_wrap(function ()
        fn.complete(startpos[2] + 1, make_completion_choices(stop.spec.choices))
    end))
end

local function mirror_stop(number)
    local stops = buf.stops
    if number < 1 or number > #stops  then
        return
    end
    local value = stops[number]
    local text = value:get_text()
    for i, stop in ipairs(stops) do
        if i > number and stop.id == value.id then
            stop:set_text(text)
        end
    end
end

local function sort_stops(stops)
    table.sort(stops, function (s1, s2)
        if s1.id == 0 then
            return false
        elseif s2.id == 0 then
            return true
        end
        return s1.id < s2.id
    end)
end

local function make_unique_ids(stops)
    local max_id = M.max_id or 0
    local id_map = {}
    for _, stop in ipairs(stops) do
        if id_map[stop.id] then
            stop.id = id_map[stop.id]
        else
            max_id = max_id + 1
            id_map[stop.id] = max_id
            stop.id = max_id
        end
    end
    M.max_id = max_id
end

local function place_stops(stops)
    sort_stops(stops)
    make_unique_ids(stops)
    local pos = buf.current_stop + 1
    for _, spec in ipairs(stops) do
        add_stop(spec, pos)
        pos = pos + 1
    end
end

-- Snippet management

local function get_snippet_at_cursor()
    local _, col = unpack(api.nvim_win_get_cursor(0))
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col + 1):match('(%S+)$')
    if word then
        local scopes = config.get_scopes()
        while #word > 0 do
            for _, scope in ipairs(scopes) do
                if scope and M.snips[scope] then
                    if M.snips[scope][word] then
                        return word, M.snips[scope][word]
                    end
                end
            end
            word = word:sub(2)
        end
    end
    return nil, nil
end

-- Public functions

function M.mirror_stops()
    if buf.current_stop ~= 0 then
        mirror_stop(buf.current_stop)
    end
end

function M.previous_stop()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) - 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop - 1
    end
    return M.jump(stop)
end

function M.next_stop()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) + 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop + 1
    end
    return M.jump(stop)
end

function M.jump(stop)
    local stops = buf.stops
    if not stops or #stops == 0 then
        return false
    end
    if buf.current_stop then
        mirror_stop(buf.current_stop)
    end
    local should_finish = false
    if #stops >= stop and stop > 0 then
        local value = stops[stop]
        local startpos, endpos = value:get_range()
        if value.spec.type == 'tabstop' or value.spec.type == 'choice' then
            if value.spec.type == 'choice' then
                start_insert(endpos)
                present_choices(value, startpos)
            else
                start_insert(startpos)
            end
            if stop == #stops then
                should_finish = true
            end
        else
            select_stop(startpos, endpos)
        end

        buf.current_stop = stop
    else
        should_finish = true
    end

    if should_finish then
        -- Start inserting at the end of the current stop
        local value = stops[buf.current_stop]
        local _, endpos = value:get_range()
        start_insert(endpos)
        buf.clear_state()
    end

    return true
end

-- Check if cursor is inside any stop
function M.check_position()
    local stops = buf.stops
    local row, col = unpack(api.nvim_win_get_cursor(0))
    row = row - 1
    for _, stop in ipairs(stops) do
        local from, to = stop:get_range()
        if (from[1] < row or (from[1] == row and from[2] <= col))
                and (to[1] > row or (to[1] == row and to[2] >= col)) then
            return
        end
    end
    buf.clear_state()
end

function M.insert_snip(word, snip)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    col = col + 1 - #word
    local current_line = api.nvim_get_current_line()
    local indent = current_line:match('^(%s+)')
    local body = {}
    if type(snip) == 'table' then
        -- Structured snippet
        body = snip.body
    else
        -- Text snippet
        body = vim.split(snip, '\n', true)
    end
    local text = table.concat(body, '\n')
    local ok, parsed, pos = parser.parse(text, 1)
    if not ok or pos <= #text then
        print_error("> Error while parsing snippet: didn't parse till end")
        return false
    end
    local builder = Builder.new({row = row, col = col, indent = indent, word = word})
    local content, stops = builder:build_snip(parsed)
    local lines = vim.split(content, '\n', true)
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    place_stops(stops)
    buf.setup_autocmds()
    M.next_stop()
    return true
end

function M.expand_or_advance()
    return M.expand() or M.next_stop()
end

function M.expand()
    local word, snip = get_snippet_at_cursor()
    if word and snip then
        return M.insert_snip(word, snip)
    end
    return false
end

function M.can_expand()
    local word, snip = get_snippet_at_cursor()
    if word and snip then
        return true
    else
        return false
    end
end

function M.can_jump(dir)
    local stops = buf.state().stops
    if dir >= 0 then
        return #stops > 0 and buf.current_stop <= #stops
    else
        return #stops > 0 and buf.current_stop > 1
    end
end

function M.can_expand_or_advance()
    return M.can_expand() or M.can_jump(1)
end

-- Setup

cmd('augroup snippy')
cmd('autocmd!')
cmd('autocmd FileType * lua snippy.read_snippets()')
cmd('augroup END')

M.snips = {}

function M.read_snippets()
    local snips = reader.read_snippets()
    M.snips = vim.tbl_extend('force', M.snips, snips)
end

config.init({})

return M

-- vim:et ts=4 sw=4
