local util = require('snippy.util')
local shared = require('snippy.shared')
local parser = require('snippy.parser')
local fn = vim.fn

---@type table<string, fun(): string?>
local varmap = {
    TM_SELECTED_TEXT = function()
        return shared.selected_text
    end,
    VISUAL = function()
        return shared.selected_text
    end,
    TM_CURRENT_LINE = function()
        return vim.api.nvim_get_current_line()
    end,
    TM_CURRENT_WORD = function()
        return fn.expand('<cword>')
    end,
    TM_LINE_INDEX = function()
        return tostring(fn.line('.') - 1)
    end,
    TM_LINE_NUMBER = function()
        return tostring(fn.line('.'))
    end,
    TM_FILENAME = function()
        return fn.expand('%:t')
    end,
    TM_FILENAME_BASE = function()
        return fn.expand('%:t:r')
    end,
    TM_DIRECTORY = function()
        return fn.expand('%:p:h:t')
    end,
    TM_FILEPATH = function()
        return fn.expand('%:p')
    end,
    CLIPBOARD = function()
        return ''
    end,
    WORKSPACE_NAME = function()
        return ''
    end,
    WORKSPACE_FOLDER = function()
        return ''
    end,
    CURRENT_YEAR = function()
        return fn.strftime('%Y')
    end,
    CURRENT_YEAR_SHORT = function()
        return fn.strftime('%y')
    end,
    CURRENT_MONTH = function()
        return fn.strftime('%m')
    end,
    CURRENT_MONTH_NAME = function()
        return fn.strftime('%B')
    end,
    CURRENT_MONTH_NAME_SHORT = function()
        return fn.strftime('%b')
    end,
    CURRENT_DATE = function()
        return fn.strftime('%d')
    end,
    CURRENT_DAY_NAME = function()
        return fn.strftime('%A')
    end,
    CURRENT_DAY_NAME_SHORT = function()
        return fn.strftime('%a')
    end,
    CURRENT_HOUR = function()
        return fn.strftime('%H')
    end,
    CURRENT_MINUTE = function()
        return fn.strftime('%M')
    end,
    CURRENT_SECOND = function()
        return fn.strftime('%S')
    end,
    CURRENT_SECONDS_UNIX = function()
        return fn.localtime()
    end,
    RANDOM = function()
        return string.format('%06d', math.random(999999))
    end,
    RANDOM_HEX = function()
        return string.format('%06x', math.random(0x1000000))
    end,
    UUID = function()
        return nil
    end,
    BLOCK_COMMENT_START = function()
        return util.parse_comment_string()['start']
    end,
    BLOCK_COMMENT_END = function()
        return util.parse_comment_string()['end']
    end,
    LINE_COMMENT = function()
        return util.parse_comment_string()['line']
    end,
}

---@class snippy.Builder Snippet renderer/builder
---@field row integer Current row
---@field col integer Current row
---@field indent string Current indent level
---@field extra_indent string
---@field stops table Tabstops/variables being built
---@field result string Snippet being rendered
local Builder = {
    row = 0,
    col = 0,
    word = '',
    indent = '',
    extra_indent = '',
}

---@param o table?
---@return snippy.Builder
function Builder.new(o)
    local builder = setmetatable(o or {}, { __index = Builder })
    builder.stops = {}
    builder.result = ''
    return builder
end

---Adds content to the final result
---@param content string
function Builder:add(content)
    self.result = self.result .. content
end

---Evaluates Vimscript code
---@param code string
---@return string # Evaluation result
function Builder:eval_vim(code)
    local ok, result = pcall(fn.eval, code)
    if ok then
        local tp = type(result)
        if tp == 'number' then
            result = tostring(result)
        elseif tp ~= 'table' and tp ~= 'string' then
            result = ''
        end
        return result
    else
        util.print_error(string.format('Invalid eval code `%s` at %d:%d: %s', code, self.row, self.col, result))
        return ''
    end
end

---Evaluates Lua code
---@param code string
---@return string # Evaluation result
function Builder:eval_lua(code)
    local ok, result = pcall(fn.luaeval, code)
    if ok then
        local tp = type(result)
        if tp == 'number' then
            result = tostring(result)
        elseif tp ~= 'table' and tp ~= 'string' then
            result = ''
        end
        ---@cast result string
        return result
    else
        util.print_error(string.format('Invalid eval code `%s` at %d:%d: %s', code, self.row, self.col, result))
        return ''
    end
end

---Indents a list of lines
---@param lines string[] Unindented lines
---@param is_expansion boolean True during eval/variable expansion, false otherwise
---@return string[] lines List of indented lines
function Builder:indent_lines(lines, is_expansion)
    local new_level
    for i, line in ipairs(lines) do
        if vim.bo.expandtab then
            line = line:gsub('\t', string.rep(' ', vim.fn.shiftwidth()))
        end
        new_level = line:match('^%s*')
        if i > 1 then
            if is_expansion and line ~= '' then
                line = self.extra_indent .. line
            end
            line = self.indent .. line
        end
        lines[i] = line
    end
    self.extra_indent = new_level
    return lines
end

---Appends a sequence of characters to the result
---@param text string|string[] Text to be appended
---@param is_expansion? boolean True during eval/variable expansion
function Builder:append_text(text, is_expansion)
    local lines = type(text) == 'string' and vim.split(text, '\n', true) or text
    ---@cast lines string[]
    lines = self:indent_lines(lines, is_expansion or false)
    self.row = self.row + #lines - 1
    if #lines > 1 then
        self.col = #lines[#lines] -- fn.strchars(lines[#lines])
    else
        self.col = self.col + #lines[1] -- fn.strchars(lines[1])
    end
    self:add(table.concat(lines, '\n'))
end

---Evaluates a variable and possibly its children
---@param variable table Variable node
function Builder:evaluate_variable(variable)
    if not varmap[variable.name] then
        self:append_text(string.format('$%s', variable.name), false)
        return
    end
    local result = varmap[variable.name] and varmap[variable.name]()
    if not result then
        self:process_structure(variable.children)
    else
        self:append_text(result, true)
    end
end

---Processes the snippet structure
---@param structure table|string The structure or string to process
---@param parent any Parent node
function Builder:process_structure(structure, parent)
    if type(structure) == 'table' then
        for _, value in ipairs(structure) do
            if type(value) == 'table' then
                if value.type == 'tabstop' then
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = { self.row, self.col },
                        endpos = { self.row, self.col },
                        transform = value.transform,
                        parent = parent,
                    })
                elseif value.type == 'placeholder' then
                    local startrow, startcol = self.row, self.col
                    self:process_structure(value.children, value.id)
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = { startrow, startcol },
                        endpos = { self.row, self.col },
                        parent = parent,
                    })
                elseif value.type == 'variable' then
                    self:evaluate_variable(value)
                elseif value.type == 'choice' then
                    local choice = value.children[1]
                    local startrow, startcol = self.row, self.col
                    self:append_text(choice)
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = { startrow, startcol },
                        endpos = { self.row, self.col },
                        choices = value.choices,
                        parent = parent,
                    })
                elseif value.type == 'eval' then
                    local code = value.children[1].raw
                    local lang = value.lang
                    local result
                    if lang == parser.EvalLang.Vimscript then
                        result = self:eval_vim(code)
                    else
                        result = self:eval_lua(code)
                    end
                    self:append_text(result, true)
                elseif value.type == 'text' then
                    local text = value.escaped
                    self:append_text(text)
                else
                    util.print_error(string.format('Unsupported element "%s" at %d:%d', value.type, self.row, self.col))
                end
            else
                self:append_text(value)
            end
        end
    else
        self:append_text(structure)
    end
end

---Adds a final ($0) tabstop if none is found
function Builder:fix_ending()
    for _, stop in ipairs(self.stops) do
        if stop.id == 0 then
            return
        end
    end
    table.insert(
        self.stops,
        { type = 'tabstop', id = 0, startpos = { self.row, self.col }, endpos = { self.row, self.col } }
    )
end

---Renders the snippet to a string
---@param structure table
---@param preview boolean? Whether it is a preview rendering
---@return string result Rendered snippet
---@return table stops List of tabstops
function Builder:build_snip(structure, preview)
    self:process_structure(structure)
    self:fix_ending()
    if not preview then
        shared.set_selection()
    end
    return self.result, self.stops
end

return Builder
