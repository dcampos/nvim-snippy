local snipmate_reader = require('snippy.reader.snipmate')
local buf = require('snippy.buf')
local shared = require('snippy.shared')
local util = require('snippy.util')
local log = require('snippy.log')

local Builder = require('snippy.builder')

local api = vim.api
local fn = vim.fn
local t = util.t

local M = {}

setmetatable(M, {
    __index = function(self, key)
        if key == 'snippets' then
            if #self._snippets == 0 then
                self.read_snippets()
            end
            return self._snippets
        end
    end,
})

-- Stop management

local function ensure_normal_mode()
    if fn.mode() ~= 'n' then
        api.nvim_feedkeys(t('<Esc>'), 'n', true)
    end
end

local function cursor_placed()
    -- The autocmds must be set up only after the cursor jumps to the tab stop
    api.nvim_feedkeys(t("<cmd>lua require('snippy.buf').setup_autocmds()<CR>"), 'n', true)
end

local function move_cursor_to(row, col, after)
    local line = fn.getline(row)
    col = math.max(fn.strchars(line:sub(1, col)) - 1, 0)
    col = after and col + 1 or col
    api.nvim_feedkeys(t(string.format('%sG0%s', row, string.rep('<Right>', col))), 'n', true)
end

local function select_stop(from, to)
    api.nvim_win_set_cursor(0, { from[1] + 1, from[2] + 1 })
    ensure_normal_mode()
    move_cursor_to(from[1] + 1, from[2] + 1, false)
    api.nvim_feedkeys(t('v'), 'n', true)
    local exclusive = vim.o.selection == 'exclusive'
    move_cursor_to(to[1] + 1, to[2], exclusive)
    api.nvim_feedkeys(t('o<c-g>'), 'n', true)
    cursor_placed()
end

local function start_insert(row, col)
    if fn.pumvisible() == 1 then
        -- Close choice (completion) menu if open
        fn.complete(fn.col('.'), {})
    end
    api.nvim_win_set_cursor(0, { row, col })
    if fn.mode() ~= 'i' then
        if fn.mode() == 's' then
            api.nvim_feedkeys(t('<Esc>'), 'nx', true)
        end
        local line = api.nvim_get_current_line()
        if col >= #line then
            vim.cmd('startinsert!')
        else
            vim.cmd('startinsert')
        end
    end
    cursor_placed()
end

local function make_completion_choices(choices)
    local items = {}
    for _, value in ipairs(choices) do
        table.insert(items, {
            word = value,
            abbr = value,
            menu = '[Snippy]',
            kind = 'Choice',
        })
    end
    return items
end

local function present_choices(stop, startpos)
    vim.defer_fn(function()
        fn.complete(startpos[2] + 1, make_completion_choices(stop.spec.choices))
    end, shared.config.choice_delay)
end

local function sort_stops(stops)
    table.sort(stops, function(s1, s2)
        if s1.id == 0 then
            return false
        elseif s2.id == 0 then
            return true
        end
        if s1.id < s2.id then
            return true
        elseif s1.id > s2.id then
            return false
        end
        if s1.transform then
            return false
        elseif s2.transform then
            return true
        end
        return util.is_before(s1.startpos, s2.startpos)
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
    for _, stop in ipairs(stops) do
        if stop.parent then
            stop.parent = id_map[stop.parent]
        end
    end
    M.max_id = max_id
end

local function place_stops(specs)
    sort_stops(specs)
    make_unique_ids(specs)
    local pos = buf.current_stop + 1
    for _, spec in ipairs(specs) do
        if buf.current_stop > 0 and not spec.parent then
            local current_stop = buf.stops[buf.current_stop]
            spec.parent = current_stop.id
            if current_stop.spec.type == 'placeholder' then
                -- If the current stop was a placeholder, we convert it to a
                -- tabstop so that its (new) children don't get cleared.
                current_stop.spec.type = 'tabstop'
            end
        end
        buf.add_stop(spec, pos)
        pos = pos + 1
    end
end

-- Snippet management

local function get_snippet_at_cursor(auto_trigger)
    local _, col = unpack(api.nvim_win_get_cursor(0))

    -- Remove leading whitespace for current_line_to_col
    local current_line_to_col = api.nvim_get_current_line():sub(1, col):gsub('^%s*', '')

    if current_line_to_col then
        if auto_trigger then
            if not shared.last_char or not vim.endswith(current_line_to_col, shared.last_char) then
                return nil, nil
            end
        end

        local word = current_line_to_col:match('(%S*)$') -- Remove leading whitespace
        local word_bound = true
        local scopes = shared.get_scopes()
        while #word > 0 do
            for _, scope in ipairs(scopes) do
                if scope and M.snippets[scope] then
                    if M.snippets[scope][word] then
                        local snippet = M.snippets[scope][word]
                        if
                            auto_trigger and snippet.option.auto_trigger
                            or not auto_trigger and not snippet.option.auto_trigger
                        then
                            local custom_expand = true
                            if snippet.option.custom then
                                for _, v in pairs(snippet.option.custom) do
                                    custom_expand = custom_expand and v()
                                end
                            end
                            if custom_expand then
                                if snippet.option.inword then
                                    -- Match inside word
                                    return word, snippet
                                elseif snippet.option.beginning then
                                    -- Match if word is first on line
                                    if word == current_line_to_col then
                                        return word, snippet
                                    end
                                else
                                    if word_bound then
                                        -- By default only match on word boundary
                                        return word, snippet
                                    end
                                end
                            end
                        end
                    end
                end
            end
            word_bound = fn.match(word, '^\\k') == -1
            word = fn.strcharpart(word, 1)
        end
    end
    return nil, nil
end

local function get_lsp_item(user_data)
    if user_data then
        if user_data.nvim and user_data.nvim.lsp then
            return user_data.nvim.lsp.completion_item
        elseif user_data.lspitem then
            local lspitem = user_data.lspitem
            return type(lspitem) == 'string' and vim.fn.json_decode(lspitem) or lspitem
        end
    end
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

function M._handle_BufWritePost()
    M._check_position()
end

-- Public functions

---Complete snippets at the current cursor position
function M.complete()
    local col = api.nvim_win_get_cursor(0)[2]
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col):match('(%S*)$')
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

---Call this on CompleteDone to expand completed snippets
function M.complete_done()
    local completed_item = vim.v.completed_item
    log.debug('complete_done', completed_item)
    if completed_item.user_data then
        local word = completed_item.word
        local user_data = completed_item.user_data
        local snippet
        if type(user_data) == 'table' then
            if user_data.snippy then
                snippet = user_data.snippy.snippet
            else
                local lsp_item = get_lsp_item(user_data) or {}
                if lsp_item.textEdit and type(lsp_item.textEdit) == 'table' then
                    snippet = lsp_item.textEdit.newText
                elseif lsp_item.insertTextFormat == 2 then
                    snippet = lsp_item.insertText
                end
            end
        end
        if snippet then
            M.expand_snippet(snippet, word)
        end
    end
end

---Returns a list of completion items in the current context
---@return table items
function M.get_completion_items()
    local items = {}
    local scopes = shared.get_scopes()

    for _, scope in ipairs(scopes) do
        if scope and M.snippets[scope] then
            for _, snip in pairs(M.snippets[scope]) do
                table.insert(items, {
                    word = snip.prefix,
                    abbr = snip.prefix,
                    kind = 'Snippet',
                    dup = 1,
                    user_data = {
                        snippy = {
                            snippet = snip,
                        },
                    },
                })
            end
        end
    end

    return items
end

---For cutting curently selected text
---@param mode string Currenct selection mode
---@param visual boolean Whether it is a visual selection
function M.cut_text(mode, visual)
    local tmpval, tmptype = fn.getreg('x'), fn.getregtype('x')
    local keys
    if visual then
        keys = 'gv'
        vim.cmd('normal! "xy')
    else
        if mode == 'line' then
            keys = "'[V']"
        elseif mode == 'char' then
            keys = '`[v`]'
        else
            return
        end
        vim.cmd('normal! ' .. keys .. '"xy')
    end
    shared.set_selection(api.nvim_eval('@x'), mode)
    fn.setreg('x', tmpval, tmptype)
    api.nvim_feedkeys(t(keys .. '"_c'), 'n', true)
end

function M._mirror_stops()
    if buf.current_stop ~= 0 then
        buf.mirror_stop(buf.current_stop)
    end
end

---Jumps to the previous valid snippet stop
---@return boolean
function M.previous()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) - 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop - 1
    end
    return M._jump(stop)
end

---Jumps to the next valid snippet stop
---@return boolean
function M.next()
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
        buf.mirror_stop(buf.current_stop)
        buf.deactivate_stops()
    end
    local should_finish = false
    if #stops >= stop and stop > 0 then
        -- Disable autocmds so we can move freely
        buf.clear_autocmds()

        buf.activate_stop(stop)
        buf.mirror_stop(stop)

        local value = stops[stop]
        local startpos, endpos = value:get_range()
        local empty = startpos[1] == endpos[1] and endpos[2] == startpos[2]

        if empty or value.spec.type == 'choice' then
            if stop == #stops then
                should_finish = true
            else
                start_insert(endpos[1] + 1, endpos[2])
            end
            if value.spec.type == 'choice' then
                present_choices(value, startpos)
            end
        else
            select_stop(startpos, endpos)
        end
        api.nvim_exec_autocmds('User', { pattern = 'SnippyJumped' })
    else
        should_finish = true
    end

    if should_finish then
        -- Start inserting at the end of the current stop
        local value = stops[buf.current_stop]
        local _, endpos = value:get_range()
        start_insert(endpos[1] + 1, endpos[2])
        buf.clear_state()
    end

    return true
end

-- Check if the cursor is inside any stop. Otherwise, clears the current snippet.
function M._check_position()
    local stops = buf.stops
    local row, col = unpack(api.nvim_win_get_cursor(0))
    row = row - 1
    local max_row = vim.api.nvim_buf_line_count(0) - 1
    for _, stop in ipairs(stops) do
        local from, to = stop:get_range()
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

        if startrow > max_row or endrow > max_row then
            break
        end

        if
            (startrow < row or (startrow == row and startcol <= col))
            and (endrow > row or (endrow == row and endcol >= col))
        then
            return
        end
    end
    buf.clear_state()
end

---Parses a snippet into an internal representation
---@param snippet string|table The snippet to parse (either text or structured)
---@return table parsed The parsed snippet representation
function M.parse_snippet(snippet)
    local ok, parsed, pos
    local text
    local parser = require('snippy.parser')
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
        error("> Error while parsing snippet: didn't parse till the end")
    end
    assert(parsed, '> Snippet could not be parsed')
    return parsed
end

---Expands a snippet at the current cursor position
---@param snippet string|table The snippet to expand
---@param word string|nil The trigger word that was matched
---@return boolean # True on success, false on failure
function M.expand_snippet(snippet, word)
    log.debug('expand_snippet', word, snippet)
    local current_line = api.nvim_get_current_line()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    if fn.mode() ~= 'i' then
        col = math.min(#current_line, col + 1)
    end
    if not word then
        word = ''
    else
        local line_to_cursor = api.nvim_get_current_line():sub(1, col)
        if not vim.endswith(line_to_cursor, word:gsub('\n', '\0')) then
            return false
        end
    end
    col = col - #word
    local indent = current_line:match('^(%s*)')
    local parsed = M.parse_snippet(snippet)
    local fixed_col = col -- fn.strchars(current_line:sub(1, col))
    local builder = Builder.new({ row = row, col = fixed_col, indent = indent, word = word })
    local content, stops = builder:build_snip(parsed)
    local lines = vim.split(content, '\n', true)
    api.nvim_set_option('undolevels', api.nvim_get_option('undolevels'))
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    place_stops(stops)
    api.nvim_exec_autocmds('User', { pattern = 'SnippyExpanded' })
    M.next()
    return true
end

---Returns a string representation of a snippet
---@param snippet string|table The snippet to represent
---@return string # The string representation
function M.get_repr(snippet)
    local parsed = M.parse_snippet(snippet)
    local builder = Builder.new({ row = 0, col = 0, indent = '', word = '' })
    local content, _ = builder:build_snip(parsed, true)
    return content
end

---Tries to expand a snippet or advance to the next stop
---@return boolean
function M.expand_or_advance()
    return M.expand() or M.next()
end

---Expands a snippet at the current cursor position if possible
---@param auto boolean|nil Whether this is an automatic expansion
---@return boolean
function M.expand(auto)
    local word, snippet = get_snippet_at_cursor(auto)
    shared.last_char = nil
    if word and snippet then
        return M.expand_snippet(snippet, word)
    end
    return false
end

---Checks if a snippet can be expanded at the current position
---@param auto boolean|nil Whether this is an automatic expansion check
---@return boolean
function M.can_expand(auto)
    local word, snip = get_snippet_at_cursor(auto)
    if word and snip then
        return true
    else
        return false
    end
end

---Checks if it's possible to jump in the specified direction
---@param dir integer The direction to check (positive for forward, negative for backward)
---@return boolean
function M.can_jump(dir)
    local stops = buf.state().stops
    if dir >= 0 then
        return #stops > 0 and buf.current_stop <= #stops
    else
        return #stops > 0 and buf.current_stop > 1
    end
end

---Checks if expansion or advancement is possible
---@return boolean
function M.can_expand_or_advance()
    return M.can_expand() or M.can_jump(1)
end

---Checks if there is any snippet active
---@return boolean
function M.is_active()
    return buf.state().active
end

-- Setup

M._snippets = {}

M.readers = {
    snipmate_reader,
}

---Loads snippets for the current scopes
function M.read_snippets()
    local scopes = shared.get_scopes()
    for _, scope in ipairs(scopes) do
        if scope and scope ~= '' and not shared.cache[scope] then
            for _, reader in ipairs(M.readers) do
                local snips = reader.read_snippets(scope)
                M._snippets[scope] = util.merge_snippets(M._snippets[scope] or {}, snips)
            end
            shared.cache[scope] = true
        end
    end
end

---Clears currently cached snippets
function M.clear_cache()
    shared.cache = {}
    M._snippets = {}
end

---For completion of snippet file names
---@param prefix string Prefix to find
---@return table results Snippet file names
function M.complete_snippet_files(prefix)
    local files = {}
    for _, reader in ipairs(M.readers) do
        vim.list_extend(files, reader.list_existing_files())
    end
    local results = {}
    for _, file in ipairs(files) do
        if file:find(prefix, 1, true) and not vim.tbl_contains(results, file) then
            table.insert(results, fn.fnamemodify(file, ':p'))
        end
    end
    return results
end

return M
