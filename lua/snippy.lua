local parser = require 'snippy.parser'
local reader = require 'snippy.reader'
local buf = require 'snippy.buf'
local shared = require 'snippy.shared'
local util = require 'snippy.util'

local Builder = require 'snippy.builder'

local api = vim.api
local fn = vim.fn
local t = util.t

local M = {}

-- Stop management

local function ensure_normal_mode()
    if fn.mode() ~= 'n' then
        api.nvim_feedkeys(t"<Esc>", 'n', true)
    end
end

local function select_stop(from, to)
    api.nvim_win_set_cursor(0, {from[1] + 1, from[2] + 1})
    ensure_normal_mode()
    api.nvim_feedkeys(t(string.format("%sG%s|", from[1] + 1, from[2] + 1)), 'n', true)
    api.nvim_feedkeys(t("v"), 'n', true)
    api.nvim_feedkeys(t(string.format("%sG%s|", to[1] + 1, to[2])), 'n', true)
    api.nvim_feedkeys(t("o<c-g>"), 'n', true)
end

local function start_insert(pos)
    -- Update cursor - so we ensure col('$') will work.
    if fn.mode() == 'i' then
        api.nvim_win_set_cursor(0, {pos[1] + 1, pos[2] + 1})
    else
        api.nvim_win_set_cursor(0, {pos[1] + 1, pos[2]})
    end
    ensure_normal_mode()
    api.nvim_feedkeys(t(string.format("%sG%s|", pos[1] + 1, pos[2] + 1)), 'n', true)
    if pos[2] + 1 >= fn.col('$') then
        api.nvim_feedkeys(t("a"), 'n', true)
    else
        api.nvim_feedkeys(t("i"), 'n', true)
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
            or util.is_before(s1.startpos, s2.startpos)
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
        buf.add_stop(spec, pos)
        pos = pos + 1
    end
end

-- Snippet management

local function get_snippet_at_cursor()
    M.read_snippets()
    local _, col = unpack(api.nvim_win_get_cursor(0))
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col):match('(%S+)$')
    if word then
        local scopes = shared.config.get_scopes()
        while #word > 0 do
            for _, scope in ipairs(scopes) do
                if scope and M.snips[scope] then
                    if M.snips[scope][word] then
                        return word, M.snips[scope][word]
                    end
                end
            end
            if word:match('^%w') then
                word = word:gsub('^%w+', '')
            else
                word = word:sub(2)
            end
        end
    end
    return nil, nil
end

-- Autocmd handlers

function M._handle_TextChanged()
    buf.fix_current_stop()
    buf.update_state()
    M._mirror_stops()
end

function M._handle_TextChangedP()
    buf.fix_current_stop()
end

function M._handle_CursorMoved()
    M._check_position()
end

-- Public functions

function M.complete()
    local col = api.nvim_win_get_cursor(0)[2]
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col):match('(%S+)$')
    local items = M.get_completion_items()
    local choices = {}
    for _, item in ipairs(items) do
        if item.word:sub(1, #word) == word then
            item.menu = '[Snippy]'
            table.insert(choices, item)
        end
    end
    fn.complete(col - #word + 1, choices)
end

function M.complete_done()
    local completed_item = vim.v.completed_item
    if completed_item.user_data then
        local word = completed_item.word
        local user_data = completed_item.user_data
        if type(user_data) == 'table' and user_data.snippy then
            local snippet = user_data.snippy.snippet
            M.expand_snippet(snippet, word)
        end
    end
end

function M.get_completion_items()
    M.read_snippets()
    local items = {}
    local scopes = shared.config.get_scopes()

    for _, scope in ipairs(scopes) do
        if scope and M.snips[scope] then
            for _, snip in pairs(M.snips[scope]) do
                table.insert(items, {
                    word = snip.prefix,
                    abbr = snip.prefix,
                    kind = 'Snippet',
                    dup = 1,
                    user_data = {
                        snippy = {
                            snippet = table.concat(snip.body, '\n')
                        }
                    }
                })
            end
        end
    end

    return items
end

function M.cut_text(mode, visual)
    local tmpval, tmptype = fn.getreg('"'), fn.getregtype('"')
    local keys
    if visual then
        keys = "gv"
        api.nvim_exec("normal! y", false)
    else
        if mode == 'line' then
            keys = "'[V']"
        elseif mode == 'char' then
            keys = "`[v`]"
        else
            return
        end
        api.nvim_exec("normal! " .. keys .. "y", false)
    end
    shared.set_selection(api.nvim_eval('@"'), mode)
    fn.setreg('"', tmpval, tmptype)
    api.nvim_feedkeys(t(keys .. '"_c'), 'n', true)
end

function M._mirror_stops()
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
    return M._jump(stop)
end

function M.next_stop()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) + 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop + 1
    end
    return M._jump(stop)
end

function M._jump(stop)
    local stops = buf.stops
    if not stops or #stops == 0 then
        return false
    end
    if buf.current_stop ~= 0 then
        mirror_stop(buf.current_stop)
        buf.deactivate_stop(buf.current_stop)
    end
    local should_finish = false
    if #stops >= stop and stop > 0 then
        local value = stops[stop]
        local startpos, endpos = value:get_range()
        local empty = startpos[1] == endpos[1] and endpos[2] == startpos[2]
        if empty or value.spec.type == 'choice' then
            start_insert(endpos)
            if value.spec.type == 'choice' then
                present_choices(value, startpos)
            end
            if stop == #stops then
                should_finish = true
            end
        else
            select_stop(startpos, endpos)
        end

        buf.activate_stop(stop)
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

-- Check if the cursor is inside any stop
function M._check_position()
    local stops = buf.stops
    local row, col = unpack(api.nvim_win_get_cursor(0))
    row = row - 1
    local ranges = {}
    for _, stop in ipairs(stops) do
        local from, to = stop:get_range()
        table.insert(ranges, {from, to})
        local startrow, startcol = unpack(from)
        local endrow, endcol = unpack(to)
        if fn.mode() == 'n' then
            if startcol + 1 == fn.col('$') then
                startcol = startcol - 1
            end
            if endcol + 1 == fn.col('$') then
                endcol = endcol - 1
            end
        end
        if (startrow < row or (startrow == row and startcol <= col))
                and (endrow > row or (endrow == row and endcol >= col)) then
            return
        end
    end
    buf.clear_state()
end

function M.expand_snippet(snippet, word)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    if fn.mode() ~= 'i' then
        col = col + 1
    end
    if not word then
        word = ''
    end
    col = col - #word
    local current_line = api.nvim_get_current_line()
    local indent = current_line:match('^(%s*)')
    local text
    local ok, parsed, pos
    if type(snippet) == 'table' then
        -- Structured snippet
        text = table.concat(snippet.body, '\n')
        if snippet.kind == 'snipmate' then
            ok, parsed, pos = parser.parse_snipmate(text, 1)
        else
            ok, parsed, pos = parser.parse(text, 1)
        end
    else
        -- Text snippet
        text = snippet
        ok, parsed, pos = parser.parse(text, 1)
    end
    if not ok or pos <= #text then
        error("> Error while parsing snippet: didn't parse till end")
        return false
    end
    local builder = Builder.new({row = row, col = col, indent = indent, word = word})
    local content, stops = builder:build_snip(parsed)
    local lines = vim.split(content, '\n', true)
    vim.o.undolevels = vim.o.undolevels
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    place_stops(stops)
    M.next_stop()
    vim.defer_fn(function ()
        buf.setup_autocmds()
    end, 200)
    return true
end

function M.expand_or_advance()
    return M.expand() or M.next_stop()
end

function M.expand()
    local word, snippet = get_snippet_at_cursor()
    if word and snippet then
        return M.expand_snippet(snippet, word)
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

function M.is_active()
    return buf.current_stop > 0 and not vim.tbl_isempty(buf.stops)
end

-- Setup

api.nvim_exec([[
    augroup snippy
    autocmd!
    autocmd FileType * lua snippy.read_snippets()
    augroup END
]], false)

M.snips = {}

function M.read_snippets()
    local snips = reader.read_snippets()
    M.snips = vim.tbl_extend('force', M.snips, snips)
end

function M.clear_cache()
    shared.cache = {}
end

function M.complete_snippet_files(prefix)
    local files = reader.list_existing_files()
    local results = {}
    for _, file in ipairs(files) do
        if file:find(prefix, 1, true) then
            table.insert(results, fn.fnamemodify(file, ':p'))
        end
    end
    return results
end

function M.setup(o)
    shared.set_config(o)
end

return M

-- vim:et ts=4 sw=4
