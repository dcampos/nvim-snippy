local util = require 'snippy.util'
local shared = require 'snippy.shared'
local inspect = vim.inspect
local fn = vim.fn

local varmap = {
    TM_SELECTED_TEXT = function () return shared.selected_text end,
    VISUAL = function () return shared.selected_text end,
    TM_CURRENT_LINE = function () return vim.api.nvim_get_current_line() end,
    TM_CURRENT_WORD = function () return '' end,
    TM_LINE_INDEX = function () return 0 end,
    TM_LINE_NUMBER = function () return 1 end,
    TM_FILENAME = function () return fn.expand('%:t') end,
    TM_FILENAME_BASE = function () return fn.expand('%:t:r') end,
    TM_DIRECTORY = function () return fn.expand('%:p:h:t') end,
    TM_FILEPATH = function () return fn.expand('%:p') end,
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

Builder = {}

function Builder.new(o)
    local builder = setmetatable(o, {__index = Builder})
    builder.stops = {}
    builder.result = ''
    builder.level_indent = ''
    return builder
end

function Builder:add(content)
    self.result = self.result .. content
end

--- Indents a list of lines.
---
--@param lines (list) A table containing lines.
--@param indent_lines (bool) Whether the lines should idented per level.
--@returns (string) The lines, indented.
function Builder:indent_lines(lines, ident_level)
    local result = {}
    local new_level
    for i, line in ipairs(lines) do
        if vim.bo.expandtab then
            line = line:gsub('\t', string.rep(' ', vim.bo.shiftwidth))
        end
        new_level = line:match('^%s*')
        if i > 1 and self.indent then
            if ident_level then
                line = self.level_indent .. line
            end
            line = self.indent .. line
        end
        table.insert(result, line)
    end
    self.level_indent = new_level
    return result
end

--- Appends a sequence of characters to the result.
---
--@param text (string) Text to be appended.
function Builder:append_text(text, ident_level)
    local lines = vim.split(text, '\n', true)
    lines = self:indent_lines(lines, ident_level)
    self.row = self.row + #lines - 1
    if #lines > 1 then
        self.col = fn.strchars(lines[#lines])
    else
        self.col = self.col + fn.strchars(lines[1])
    end
    self:add(table.concat(lines, '\n'))
end

--- Evaluates a variable and possibly its children.
---
--@param variable (string) Variable name.
function Builder:evaluate_variable(variable)
    local result = varmap[variable.name] and varmap[variable.name]()
    if not result then
        self:process_structure(variable.children)
    else
        self:append_text(result, true)
    end
end

function Builder:process_structure(structure)
    if type(structure) == 'table' then
        for _, value in ipairs(structure) do
            if type(value) == 'table' then
                if value.type == 'tabstop' then
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = {self.row, self.col},
                        endpos = {self.row, self.col},
                        placeholder = '',
                        transform = value.transform
                    })
                elseif value.type == 'placeholder' then
                    local startrow, startcol = self.row, self.col
                    self:process_structure(value.children)
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = {startrow, startcol},
                        endpos = {self.row, self.col}
                    })
                elseif value.type == 'variable' then
                    local startrow, startcol = self.row, self.col
                    self:evaluate_variable(value)
                    -- table.insert(self.stops, {type=value.type, id=value.id, startpos={startrow, startcol}, endpos={self.row, self.col}, tranform=value.transform})
                elseif value.type == 'choice' then
                    local choice = value.children[1]
                    local startrow, startcol = self.row, self.col
                    self:append_text(choice)
                    table.insert(self.stops, {
                        type = value.type,
                        id = value.id,
                        startpos = {startrow, startcol},
                        endpos = {self.row, self.col},
                        choices = value.choices
                    })
                elseif value.type == 'eval' then
                    local text = fn.eval(value.children[1].escaped) or ''
                    self:append_text(text)
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

function Builder:fix_ending()
    for _, stop in ipairs(self.stops) do
        if stop.id == 0 then
            return
        end
    end
    table.insert(self.stops, {type='tabstop', id=0, startpos={self.row, self.col}, endpos={self.row, self.col}})
end

function Builder:build_snip(structure)
    self:process_structure(structure)
    self:fix_ending()
    shared.set_selection()
    return self.result, self.stops
end

return Builder
