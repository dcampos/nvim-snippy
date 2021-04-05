---
---

local parser = require 'snippy.parser'
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local inspect = vim.inspect

local varmap = {
    TM_SELECTED_TEXT = function () return '' end,
    TM_CURRENT_LINE = function () return vim.api.nvim_get_current_line() end,
    TM_CURRENT_WORD = function () return '' end,
    TM_LINE_INDEX = function () return 0 end,
    TM_LINE_NUMBER = function () return 1 end,
    TM_FILENAME = function () return vim.fn.expand('%:t') end,
    TM_FILENAME_BASE = function () return vim.fn.expand('%:t:r') end,
    TM_DIRECTORY = function () return vim.fn.expand('%:p:h:t') end,
    TM_FILEPATH = function () return vim.fn.expand('%:p') end,
    CLIPBOARD = function () return '' end,
    WORKSPACE_NAME = function () return '' end,
    WORKSPACE_FOLDER = function () return '' end,
    CURRENT_YEAR = function () return fn.strftime('%Y') end,
    CURRENT_YEAR_SHORT = function () return fn.strftime('%y') end,
    CURRENT_MONTH = function () return fn.strftime('%m') end,
    CURRENT_MONTH_NAME = function () return fn.strftime('%B') end,
    CURRENT_MONTH_NAME_SHORT = function () return fn.strftime('%b') end,
    CURRENT_DATE = function () return fn.strftime('%d') end,
    CURRENT_DAY_NAME = function () return fn.strftime('%A') end,
    CURRENT_DAY_NAME_SHORT = function () return fn.strftime('%a') end,
    CURRENT_HOUR = function () return fn.strftime('%H') end,
    CURRENT_MINUTE = function () return fn.strftime('%M') end,
    CURRENT_SECOND = function () return fn.strftime('%S') end,
    CURRENT_SECONDS_UNIX = function () return fn.localtime() end,
    RANDOM = function () return math.random() end,
    RANDOM_HEX = function () return nil end,
    UUID = function () return nil end,
    BLOCK_COMMENT_START = function () return '/*' end,
    BLOCK_COMMENT_END = function () return '*/' end,
    LINE_COMMENT = function () return '//' end,
}

local M = {}

-- TODO: make buffer local
M.stops = {}

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
        elseif line:sub(1,1) ~= '#' then
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

Stop = {id=-1, mark=nil, choices=nil, transform=nil}
Stop.__index = Stop

function Stop.new(o)
    return setmetatable(o, Stop)
end

function Stop:get_range()
    local mark = api.nvim_buf_get_extmark_by_id(0, M.namespace, self.mark, {details=true})
    if #mark then
        local startrow, startcol = mark[1], mark[2]
        local endrow, endcol = mark[3].end_row, mark[3].end_col
        return {startrow, startcol}, {endrow, endcol}
    end
    return nil
end

function Stop:get_text()
    local startpos, endpos = self:get_range()
    local lines = api.nvim_buf_get_lines(0, startpos[1], endpos[1] + 1, false)
    lines[#lines] = lines[#lines]:sub(1, endpos[2])
    lines[1] = lines[1]:sub(startpos[2] + 1)
    return table.concat(lines, '\n')
end

function Stop:set_text(text)
    local startpos, endpos = self:get_range()
    if self.transform then
        -- print('transforming text for', vim.inspect(self))
        local transform = self.transform
        text = fn.substitute(text, transform.regex.raw, transform.format.escaped, transform.flags)
    end
    local lines = vim.split(text, '\n', true)
    api.nvim_buf_set_text(0, startpos[1], startpos[2], endpos[1], endpos[2], lines)
end

local function add_stop(spec)
    local startrow = spec.startpos[1] - 1
    local startcol = spec.startpos[2]
    local endrow = spec.endpos[1] - 1
    local endcol = spec.endpos[2]
    print(string.format('=> Placing spec @ %d:%d-%d:%d', startrow, startcol, endrow, endcol))
    local stops = M.stops or {}
    local end_col = endcol
    local smark = api.nvim_buf_set_extmark(0, M.namespace, startrow, startcol, {
        end_line = endrow;
        end_col = end_col;
        hl_group = 'Search';
        right_gravity = false;
        end_right_gravity = true;
    })
    table.insert(stops, Stop.new({id=spec.id, mark=smark, choices=spec.choices, transform=spec.transform}))
    M.stops = stops
end

-- local function show_stops()
--     for _, stop in pairs(M.stops) do
--         print(vim.inspect(stop))
--         local startpos, endpos = stop:get_range()
--         api.nvim_buf_add_highlight(0, M.hlnamespace, 'Cursor', startpos[1], startpos[2], endpos[2])
--     end
-- end

local function clear_stops()
    for _, stop in pairs(M.stops) do
        -- print('Clearing marks', vim.inspect(stop))
        api.nvim_buf_del_extmark(0, M.namespace, stop.mark)
    end
    M.current_stop = 0
    M.stops = {}
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
        fn.complete(startpos[2] + 1, make_completion_choices(stop.choices))
    end))
end

local function mirror_stop(number)
    local stops = M.stops
    if number < 1 or number > #stops  then
        return
    end
    local value = stops[number]
    local text = value:get_text()
    for i, stop in ipairs(stops) do
        if i > number and stop.id == value.id then
            -- print('> setting text <', text, '> for stop', i)
            stop:set_text(text)
        end
    end
end

function M.jump(stop)
    local stops = M.stops
    if not stops or not #stops then
        return
    end
    -- print('> #stops =', #stops, '- stops =', vim.inspect(stops), '- stop =', stop)
    if vim.b.current_stop then
        mirror_stop(vim.b.current_stop)
    end
    if #stops >= stop and stop > 0 then
        -- print('> Jumping to stop', stop)
        local value = stops[stop]
        local startpos, endpos = value:get_range()
        -- api.nvim_feedkeys(t'<Esc>', 'i', true)
        -- print('> startpos =', vim.inspect(startpos))
        -- print('> endpos =', vim.inspect(endpos))
        if startpos[1] == endpos[1] and startpos[2] >= endpos[2] then
            start_insert(startpos)
        elseif value.choices then
            start_insert(endpos)
            present_choices(value, startpos)
        else
            select_stop(startpos, endpos)
        end
        vim.b.current_stop = stop
    else
        -- Start inserting at the end of the current stop
        local value = stops[vim.b.current_stop]
        local _, endpos = value:get_range()
        start_insert(endpos)
        vim.b.current_stop = 0
        clear_stops()
    end
end

-- Snippet expanding

Builder = {input='', row=nil, col=nil, indent=''}
Builder.__index = Builder

function Builder.new(o)
    local builder = setmetatable(o, Builder)
    builder.stops = {}
    builder.result = ''
    return builder
end

function Builder:add(content)
    print('> result (add) =', inspect(self.result))
    self.result = self.result .. content
end

function Builder:indent_lines(lines)
    local result = {}
    for i, line in ipairs(lines) do
        if vim.bo.expandtab then
            line = line:gsub('\t', string.rep(' ', vim.bo.shiftwidth))
        end
        if i > 1 and self.indent then
            line = self.indent .. line
        end
        table.insert(result, line)
    end
    return result
end

function Builder:append_text(text)
    print('> result (append_text) =', inspect(self.result))
    local lines = vim.split(text, '\n', true)
    lines = self:indent_lines(lines)
    self.row = self.row + #lines - 1
    if #lines > 1 then
        self.col = #lines[#lines]
    else
        self.col = self.col + #lines[1]
    end
    self:add(table.concat(lines, '\n'))
end

function Builder:evaluate_variable(variable)
    local result = varmap[variable.name] and varmap[variable.name]()
    if not result then
        self:process_structure(variable.children)
    else
        self:append_text(result)
    end
end

function Builder:process_structure(structure)
    print('> process structure at', self.row, ':', self.col)
    print('> result =', inspect(self.result))
    -- print(vim.inspect(structure))
    for _, value in ipairs(structure) do
        if type(value) == 'table' then
            print('> type =', inspect(value.type))
            if value.type == 'tabstop' then
                table.insert(self.stops, {id=value.id, startpos={self.row, self.col}, endpos={self.row, self.col}, placeholder='', transform=value.transform})
            elseif value.type == 'placeholder' then
                local startrow, startcol = self.row, self.col
                self:process_structure(value.children)
                table.insert(self.stops, {id=value.id, startpos={startrow, startcol}, endpos={self.row, self.col}})
            elseif value.type == 'variable' then
                local startrow, startcol = self.row, self.col
                self:evaluate_variable(value)
                table.insert(self.stops, {id=value.id, startpos={startrow, startcol}, endpos={self.row, self.col}, tranform=value.transform})
            elseif value.type == 'choice' then
                local choice = value.children[1]
                local startrow, startcol = self.row, self.col
                self:append_text(choice)
                table.insert(self.stops, {id=value.id, startpos={startrow, startcol}, endpos={self.row, self.col}, choices=value.choices})
            elseif value.type == 'eval' then
                local text = fn.eval(value.children[1].escaped) or ''
                self:append_text(text)
            elseif value.type == 'text' then
                local text = value.escaped
                self:append_text(text)
            else
                print_error(string.format('Unsupported element "%s" at %d:%d', value.type, self.row, self.col))
            end
        end
    end
end

function Builder:build_snip(structure)
    print('> process snip at', self.row, ':', self.col)
    print('> result =', inspect(self.result))
    self:process_structure(structure)
    return self.result, self.stops
end

local function place_stops(ts_map)
    for _, ts in ipairs(ts_map) do
        -- print(string.format('=> id: %s @ %d:%d', ts.id, ts.startpos[1], ts.startpos[2]))
        add_stop(ts)
    end
end

function M.expand_snip(word, snip)
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
        return
    end
    local builder = Builder.new({row = row, col = col, indent = indent, result = ''})
    local processed, ts_map = builder:build_snip(parsed)
    -- print('> text =', i(text))
    -- print('> strutcure =', i(parsed))
    -- print('> processed =', i(processed))
    local lines = vim.split(processed, '\n', true)
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    place_stops(ts_map)
    api.nvim_win_set_cursor(0, {row, col})
    M.next_stop()
    return ''
end

function M.expand_or_next()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col + 1):match('(%w+)$')
    if word then
        local ftype = vim.bo.filetype
        if ftype and M.snips[ftype] then
            local snip = M.snips[ftype][word]
            if snip then
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
