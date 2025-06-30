local util = require('snippy.util')
local shared = require('snippy.shared')
local EvalLang = require('snippy.parser.common').EvalLang
local fn = vim.fn

-- =============================================================================
-- Helper functions
-- =============================================================================

local function uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local generated = template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
    return generated
end

---Helper function to apply transformation to content
---@param content string
---@param transform table Transformation to be applied
local function apply_transform(content, transform)
    if not transform then
        return content
    end
    return fn.substitute(content, transform.regex, transform.format, transform.flags)
end

---Calculates the new position after `content` is added
---@param content string
---@param start_row integer
---@param start_col integer
---@return integer, integer
local function calculate_position(content, start_row, start_col)
    local lines = vim.split(content, '\n', { plain = true })
    local new_row = start_row + #lines - 1
    local new_col = (#lines > 1 and #lines[#lines]) or (start_col + #content)
    return new_row, new_col
end

---Normalizes evaluation results to strings
---@param result any
---@return string
local function normalize_eval_result(result)
    local result_type = type(result)
    if result_type == 'number' then
        return tostring(result)
    elseif result_type == 'string' then
        return result
    else
        return ''
    end
end

-- =============================================================================
-- Variable registry
-- =============================================================================

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
        return vim.fn.getreg(vim.v.register)
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
        return tostring(fn.localtime())
    end,
    RANDOM = function()
        return string.format('%06d', math.random(999999))
    end,
    RANDOM_HEX = function()
        return string.format('%06x', math.random(0x1000000))
    end,
    UUID = uuid,
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

-- =============================================================================
-- Builder
-- =============================================================================

---@class snippy.NodeSpec
---@field type string
---@field id number?
---@field startpos [integer, integer]
---@field endpos [integer, integer]
---@field children snippy.NodeSpec[]?
---@field transform table?
---@field choices string[]?
---@field parent snippy.NodeSpec
---@field content string?
---@field is_mirror boolean?

---@class snippy.Builder Snippet renderer/builder
---@field row integer Current row
---@field col integer Current row
---@field indent string Current indent level
---@field extra_indent string
---@field nodes snippy.NodeSpec[] Tabstops/variables being built
---@field node_lookup table<integer, table> Tabstops/variables being built
---@field result string Snippet being rendered
local Builder = {}

---@param o table?
---@return snippy.Builder
function Builder.new(o)
    local builder = setmetatable(o or {}, { __index = Builder })
    builder.row = builder.row or 0
    builder.col = builder.col or 0
    builder.word = builder.word or ''
    builder.indent = builder.indent or ''
    builder.extra_indent = ''
    builder.nodes = {}
    builder.node_lookup = {}
    builder.result = ''
    return builder
end

---Adds content to the final result
---@param content string
function Builder:add(content)
    self.result = self.result .. content
    return content
end

---Evaluates Vimscript code
---@param code string
---@return string # Evaluation result
function Builder:eval_vim(code)
    local ok, result = pcall(fn.eval, code)
    if ok then
        result = normalize_eval_result(result)
        return result
    else
        vim.notify(string.format('Invalid Vim code `%s`: %s', code, result), vim.log.levels.ERROR)
        return ''
    end
end

---Evaluates Lua code
---@param code string
---@return string # Evaluation result
function Builder:eval_lua(code)
    local func, err = loadstring('return ' .. code)
    if not func then
        vim.notify('Lua compile error: ' .. err, vim.log.levels.ERROR)
        return ''
    end
    local ok, result = pcall(func)
    if ok then
        result = normalize_eval_result(result)
        return result
    else
        vim.notify(string.format('Invalid Lua code `%s`: %s', code, result), vim.log.levels.ERROR)
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
---@return table
function Builder:process_text(text, is_expansion)
    local lines = type(text) == 'string' and vim.split(text, '\n', { plain = true }) or text
    ---@cast lines string[]
    lines = self:indent_lines(lines, is_expansion or false)
    local result, row, col = table.concat(lines, '\n'), #lines - 1, #lines[#lines]
    return { type = 'text', content = result, endpos = { row, col } }
end

---Evaluates a variable and possibly its children
---@param variable table Variable node
---@return table
function Builder:evaluate_variable(variable)
    if not varmap[variable.name] then
        return self:process_text(string.format('$%s', variable.name), false)
    end
    local result = varmap[variable.name] and varmap[variable.name]()
    if not result then
        return self:process_nodes(variable.children)
    else
        if variable.transform then
            result = apply_transform(result, variable.transform)
        end
        return self:process_text(result, true)
    end
end

---Processes nodes and returns an intermediate structure
---@param node table
---@param parent integer? Parent ID/index
---@return table
function Builder:process_nodes(node, parent)
    local result = {}
    if type(node) == 'table' then
        for _, value in ipairs(node) do
            if type(value) == 'table' then
                if value.type == 'tabstop' or value.type == 'placeholder' then
                    local content = value.children and self:process_nodes(value.children, value.id) or {}
                    local is_mirror = (self.node_lookup[value.id] or value.transform) and true or false
                    local n = {
                        type = value.type,
                        id = value.id,
                        transform = value.transform,
                        parent = parent,
                        children = content,
                        is_mirror = is_mirror,
                    }
                    table.insert(result, n)
                    if not is_mirror then
                        self.node_lookup[value.id] = n
                    end
                elseif value.type == 'choice' then
                    local choice = value.children[1]
                    local content = self:process_text(choice)
                    local n = {
                        type = value.type,
                        id = value.id,
                        choices = value.choices,
                        parent = parent,
                        children = { content },
                        is_mirror = false,
                    }
                    table.insert(result, n)
                    self.node_lookup[value.id] = n
                elseif value.type == 'variable' then
                    local r = self:evaluate_variable(value)
                    table.insert(result, r)
                elseif value.type == 'eval' then
                    local code = value.children[1].raw
                    local lang = value.lang
                    local content
                    if lang == EvalLang.Vimscript then
                        content = self:eval_vim(code)
                    else
                        content = self:eval_lua(code)
                    end
                    table.insert(result, self:process_text(content, true))
                elseif value.type == 'text' then
                    local text = value.escaped
                    table.insert(result, self:process_text(text))
                else
                    vim.notify(string.format('Unsupported element "%s"', vim.inspect(value)), vim.log.levels.ERROR)
                end
            else
                -- Text node
                table.insert(result, self:process_text(value))
            end
        end
    else
        table.insert(result, self:process_text(node))
    end

    return result
end

---Resolves mirror content. There are two kinds of mirrors:
--- - Backward references: the target node comes before. Just fetch the content and do any transformation.
--- - Forward referentes: these need to evaluate their target nodes without appending any content or node.
---@param node table Mirror node
---@return string
function Builder:resolve_mirror_content(node)
    local target = assert(self.node_lookup[node.id], string.format('Mirror target not found for id: %s', node.id))

    local content = target.content or self:resolve_content(target, true)

    if node.transform then
        content = apply_transform(content, node.transform)
    end

    return content
end

---Resolves content for a node or list of nodes
---@param node table
---@param for_mirror boolean? Whether it is content for a mirror
---@return string
function Builder:resolve_content(node, for_mirror)
    local content = ''

    if not node.type then
        -- Multiple nodes
        for _, child in ipairs(node) do
            content = content .. self:resolve_content(child, for_mirror)
        end
    elseif node.type == 'text' then
        -- Text nodes
        content = node.content
        local rows, chars = unpack(node.endpos)
        self.row = self.row + rows
        self.col = (rows > 0 and chars) or (self.col + chars)
        if not for_mirror then
            self:add(content)
        end
    else
        -- Tabstop, placeholder or choice

        assert(type(node) == 'table', string.format('Expected node as table, got %s', type(node)))

        -- Store starting position
        local start_row, start_col = self.row, self.col
        node.startpos = { start_row, start_col }

        if node.is_mirror then
            content = self:resolve_mirror_content(node)
            self.row, self.col = calculate_position(content, start_row, start_col)

            if not for_mirror then
                self:add(content)
            end
        else
            assert(
                type(node.children) == 'table',
                string.format('Expected node children as table, got %s', type(node.children))
            )

            -- Process children nodes
            content = content .. self:resolve_content(node.children, for_mirror)
        end

        node.endpos = { self.row, self.col }
        node.content = content

        if not for_mirror then
            table.insert(self.nodes, node)
        end
    end

    return content
end

---Processes structure and assembles the final snippet (text and nodes)
---@param structure table
function Builder:process_structure(structure)
    -- Preprocess nodes, evaluating code blocks and variables in the way
    local result = self:process_nodes(structure)

    -- Assemble the final snippet
    self:resolve_content(result)
end

---Adds a final ($0) tabstop if none is found
function Builder:fix_ending()
    for _, stop in ipairs(self.nodes) do
        if stop.id == 0 then
            return
        end
    end
    table.insert(
        self.nodes,
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
        -- Empty current selection
        shared.set_selection()
    end
    return self.result, self.nodes
end

return Builder
