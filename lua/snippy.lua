---
---

local parser = require 'snippy.parser'
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

-- Loading

local function read_snippets_file(snippets_file)
    local ftype = fn.fnamemodify(snippets_file, ':t:r')
    local snips = {}
    local current = nil
    for line in io.lines(snippets_file) do
        if line:sub(1, 7) == 'snippet' then
            local prefix = line:match(' +(%w+) *')
            current = prefix
            local description = line:match(' *"(.+)" *$')
            snips[prefix] = {prefix=prefix, description = description, body = {}}
        else
            local value = line:gsub('^\t', '')
            if current then
                table.insert(snips[current].body, value)
            end
        end
    end
    M.snips[ftype] = snips
end

local function read_snips()
    for _,file in ipairs(vim.split(fn.glob('snips/*.snippets'), '\n', true)) do
        read_snippets_file(file)
    end
end

-- Stop management

local function add_stop(stop)
    api.nvim_win_set_cursor(0, {stop.startpos[1], 0})
    local lnum = stop.startpos[1] - 1
    local startcol = stop.startpos[2]
    local endcol = stop.endpos[2]
    print(string.format('=> Placing stop @ %d:%d-%d', lnum, startcol, endcol))
    print(api.nvim_get_current_line())
    local stops = vim.b.stops or {}
    local end_col = endcol
    if end_col >= fn.col('$') then
        end_col = fn.col('$') - 1
    end
    print(string.format('startcol=%d, end_col=%d, $=%d, line=%d', startcol, end_col, fn.col('$'), fn.line('.')))
    local smark = api.nvim_buf_set_extmark(0, M.namespace, lnum, startcol, {end_line=lnum, end_col=end_col, hl_group='Search', right_gravity=false, end_right_gravity=true})
    local emark = api.nvim_buf_set_extmark(0, M.namespace, lnum, endcol, {})
    table.insert(stops, {id=stop.id, startmark=smark, endmark=emark, choices=stop.choices})
    vim.b.stops = stops
end

local function show_stops()
    for _, stop in pairs(vim.b.stops) do
        print(vim.inspect(stop))
        local smarkid, emarkid = stop.startmark, stop.endmark
        local smark = api.nvim_buf_get_extmark_by_id(0, M.namespace, smarkid, {})
        local emark = api.nvim_buf_get_extmark_by_id(0, M.namespace, emarkid, {})
        api.nvim_buf_add_highlight(0, M.hlnamespace, 'Cursor', smark[1], smark[2], emark[2])
    end
end

local function clear_stops()
    for _, stop in pairs(vim.b.stops) do
        print('Clearing marks', vim.inspect(stop))
        api.nvim_buf_del_extmark(0, M.namespace, stop.startmark)
        api.nvim_buf_del_extmark(0, M.namespace, stop.endmark)
    end
    vim.b.stops = {}
end

function M.previous_stop()
    local stop = (vim.b.current_stop or 0) - 1
    M.jump(stop)
end

function M.next_stop()
    local stop = (vim.b.current_stop or 0) + 1
    M.jump(stop)
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
    local line = api.nvim_get_current_line()
    if pos[2] > #line then
        api.nvim_input("a")
    else
        api.nvim_input("i")
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
        fn.complete(startpos[2] + 1, make_completion_choices(stop.choices))
    end))
end

function M.get_stop_text(stop)
    local smark = api.nvim_buf_get_extmark_by_id(0, M.namespace, stop.startmark, {})
    local emark = api.nvim_buf_get_extmark_by_id(0, M.namespace, stop.endmark, {})
    local lines = api.nvim_buf_get_lines(0, smark[1], emark[1] + 1, false)
    lines[#lines] = lines[#lines]:sub(1, emark[2])
    lines[1] = lines[1]:sub(smark[2] + 1)
    return lines
end

function M.set_stop_text(stop, lines)
    local smark = api.nvim_buf_get_extmark_by_id(0, M.namespace, stop.startmark, {})
    local emark = api.nvim_buf_get_extmark_by_id(0, M.namespace, stop.endmark, {})
    api.nvim_buf_set_text(0, smark[1], smark[2], emark[1], emark[2], lines)
end

local function mirror_stop(number)
    local stops = vim.b.stops
    if number < 0 or number > #stops  then
        return
    end
    local value = stops[number]
    local text = M.get_stop_text(value)
    for i, stop in ipairs(stops) do
        if i > number and stop.id == value.id then
            print('> setting text <', table.concat(text, '\n'), '> for stop', i)
            M.set_stop_text(stop, text)
        end
    end
end

function M.jump(stop)
    local stops = vim.b.stops
    if not stops or not #stops then
        return
    end
    print('> #stops =', #stops, '- stops =', vim.inspect(stops), '- stop =', stop)
    if vim.b.current_stop then
        mirror_stop(vim.b.current_stop)
    end
    if #stops >= stop and stop > 0 then
        print('> Jumping to stop', stop)
        local value = stops[stop]
        local smark = api.nvim_buf_get_extmark_by_id(0, M.namespace, value.startmark, {})
        local emark = api.nvim_buf_get_extmark_by_id(0, M.namespace, value.endmark, {})
        -- api.nvim_feedkeys(t'<Esc>', 'i', true)
        print('> smark =', vim.inspect(smark))
        print('> emark =', vim.inspect(emark))
        if smark[1] == emark[1] and smark[2] >= emark[2] then
            start_insert(smark)
        elseif value.choices then
            start_insert(emark)
            present_choices(value, smark)
        else
            select_stop(smark, emark)
        end
        vim.b.current_stop = stop
    else
        vim.b.current_stop = 0
        clear_stops()
    end
end

-- Snippet expanding

local function indent_snip(body, indent)
    local lines = {}
    for i, line in ipairs(body) do
        if vim.bo.expandtab then
            line = line:gsub('\t', string.rep(' ', vim.bo.shiftwidth))
        end
        if i > 1 and indent then
            line = indent .. line
        end
        table.insert(lines, line)
    end
    return lines
end

local function process_structure(structure, row, col)
    print('> process structure at', row, ':', col)
    local stops = {}
    local result =  ''
    -- print(vim.inspect(structure))
    for _, value in ipairs(structure) do
        if type(value) == 'table' then
            if value.type == 'tabstop' then
                local stopname = '' -- 'stop' .. value.id
                result = result .. stopname
                table.insert(stops, {id=value.id, startpos={row, col}, endpos={row, col}, placeholder=stopname})
                col = col + #stopname
            elseif value.type == 'placeholder' then
                -- local stopname = value.value[1] or ''
                local inner, ts, r, c = process_structure(value.value, row, col)
                result = result .. inner
                table.insert(stops, {id=value.id, startpos={row, col}, endpos={r, c}, placeholder=inner})
                row = r
                col = c
                vim.list_extend(stops, ts)
            elseif value.type == 'choice' then
                local choice = value.value[1]
                local endcol = col + #choice
                table.insert(stops, {id=value.id, startpos={row, col}, endpos={row, endcol}, placeholder=choice, choices=value.value})
                result = result .. choice
                col = col + #choice
            elseif value.type == 'eval' then
                local evaluated = fn.eval(value.value) or ''
                result = result .. evaluated
                col = col + #evaluated
            else
                print_error(string.format('Unsupported element "%s" at %d:%d', value.type, row, col))
            end
        else
            local lines = vim.split(value, '\n')
            result = result .. value
            row = row + #lines - 1
            if #lines > 1 then
                col = #lines[#lines]
            else
                col = col + #lines[#lines]
            end
        end
    end
    return result, stops, row, col
end

local function process_snip(structure, row, col)
    local result, stops, _, _ = process_structure(structure, row, col)
    return result, stops
end

local function place_stops(ts_map)
    for _, ts in ipairs(ts_map) do
        print(string.format('=> id: %s @ %d:%d', ts.id, ts.startpos[1], ts.startpos[2]))
        add_stop(ts)
    end
end

function M.expand_snip(word, snip)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    col = col + 1 - #word
    print('row=', row, 'col=', col)
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
    local lines = indent_snip(body, indent)
    local _, parsed, _ = parser.parse(table.concat(lines, '\n'), 1)
    local processed, ts_map = process_snip(parsed, row, col)
    -- print(vim.inspect(ts_map))
    -- print(vim.inspect(processed))
    lines = vim.split(processed, '\n', true)
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    place_stops(ts_map)
    api.nvim_win_set_cursor(0, {row, col})
    M.next_stop()
    return ''
end

function M.expand_or_next()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    print('row=', row, 'col=', col)
    local current_line = api.nvim_get_current_line()
    print(current_line)
    local word = current_line:sub(1, col + 1):match('(%w+)$')
    if word then
        local ftype = vim.bo.filetype
        if ftype and M.snips[ftype] then
            print('snips found for', ftype)
            local snip = M.snips[ftype][word]
            if snip then
                print('snip found for word',  word)
                return M.expand_snip(word, snip)
            end
        end
    end
    return M.next_stop()
end

-- Setup

M.snips = {}

function M.init()
    M.namespace = api.nvim_create_namespace('snips')
    M.hlnamespace = api.nvim_create_namespace('snipshl')

    -- TODO: use <cmd>?
    api.nvim_set_keymap("i", "<c-]>", "<Esc>:lua return snippy.expand_or_next()<CR>", {
        noremap = true;
        silent = true;
    })

    api.nvim_set_keymap("i", "<c-b>", "<Esc>:lua return snippy.previous_stop()<CR>", {
        noremap = true;
        silent = true;
    })

    api.nvim_set_keymap("s", "<c-]>", "<Esc>:<C-u>lua return snippy.next_stop()<CR>", {
        noremap = true;
        silent = true;
    })

    api.nvim_set_keymap("s", "<c-b>", "<Esc>:<C-u>lua return snippy.previous_stop()<CR>", {
        noremap = true;
        silent = true;
    })

    read_snips()
end

M.init()

return M

-- vim:et ts=4 sw=4
