local lpeg = vim.lpeg
local EvalLang = require('snippy.parser.common').EvalLang

local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Ct, Cg, Cs, Cf = lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cs, lpeg.Cf

---@alias LpegPattern Pattern|vim.lpeg.Pattern

-- stylua: ignore start

-- Helper patterns
local digit = R('09')
local letter = R('az', 'AZ')
local alnum = letter + digit + P('_')
local ws = S(' \t\n\r')^1

--- Escapes a set of symbols
---@param symbols string
---@return LpegPattern
local function escape(symbols)
    return P('\\') * C(S(symbols))
end

--- Captures text into a table with escaped (clean) and raw versions
--- Note: this is kept for compatibility reasons with the legacy parser. It's not clear whether or not we
--- should ever use a 'raw' version of the text, as most of the time the clean version should be enough.
---@param delimiters string Characters to stop matching at
---@param escaped string? Characters to escape when capturing text (defaults to delimiters)
---@return table
local function text(delimiters, escaped)
    escaped = escaped or delimiters .. '\\'
    local escaped_chars = escape(escaped) / function(c)
        return { c = c, e = '\\' .. c }
    end
    local delimiter_chars = (1 - S(delimiters)) / function(c)
        return { c = c }
    end
    return Cf(Ct('') * (escaped_chars + delimiter_chars)^1, function(acc, val)
        acc.raw = (acc.raw or '') .. (val.e or val.c)
        acc.escaped = (acc.escaped or '') .. val.c
        return acc
    end) / function(t)
        return { type = 'text', raw = t.raw, escaped = t.escaped }
    end
end

--- Captures clean text (escape chars removed)
---@param delimiters string
---@param escaped string?
---@return LpegPattern
local function text_clean(delimiters, escaped)
    local escaped_chars = escape(escaped or delimiters .. '\\') / function(s) return s end
    return Cs((escaped_chars + (1 - S(delimiters)))^1)
end

--- Capturs raw srings (escape chars kept)
---@param delimiters string
---@param escaped string?
---@return LpegPattern
local function text_raw(delimiters, escaped)
    local escaped_chars = escape(escaped or delimiters .. '\\')
    return Cs((escaped_chars + (1 - S(delimiters)))^1)
end

-- Grammar definition
local base_rules = {
    'any', -- Entry point

    any = Ct(((V('nodes') + V('outer_text'))^0) * -1),
    nodes = (V('tabstop') + V('placeholder') + V('choice') + V('variable'))^1,

    tabstop = Ct(
        (P('$') * V('int')) +
        (P('${') * V('int') * V('transform')^-1 * P('}'))
    ) / function(t)
            return { type = 'tabstop', id = t[1], transform = t[2], children = {} }
        end,

    placeholder = Ct(P('${') * V('int') * P(':') * V('children') * P('}')) /
        function(t)
            return { type = 'placeholder', id = t[1], children = t[2] }
        end,

    choice = Ct(P('${') * V('int') * P('|') * Ct(V('choice_text') * (ws^0 * ',' * ws^0 * V('choice_text'))^0) * P('|}')) /
        function(t)
            return { type = 'choice', id = t[1], choices = t[2], children = { t[2][1] } }
        end,

    variable = Ct(
        (P('$') * V('var')) +
        (P('${') * V('var') * P('}')) +
        (P('${') * V('var') * P(':') * Cg(V('children'), 'children') * P('}')) +
        (P('${') * V('var') * Cg(V('transform'), 'transform') * P('}'))
    ) / function(t)
            return { type = 'variable', name = t[1], children = t.children or {}, transform = t.transform }
        end,

    transform = Ct(P('/') * V('regex') * P('/') * (Ct(V('format')^1) + V('replacement')) * (P('/') * V('flags'))^-1) /
        function(t)
            return { type = 'transform', regex = t[1], format = t[2], flags = t[3] or '' }
        end,

    format = Ct(
        (P('$') * V('int')) +
        (P('${') * V('int') * P('}')) +
        (P('${') * V('int') * P(':/') * V('modifier') * P('}')) +
        (P('${') * V('int') * P(':+') * V('if') * P('}')) +
        (P('${') * V('int') * P(':?') * V('if') * P(':') * V('else') * P('}')) +
        (P('${') * V('int') * (P(':-') + P(':')) * V('else') * P('}'))
    ) / function(t)
            if t.modifier then
                return { type = 'format', id = t[1], modifier = t.modifier }
            elseif t['if'] and t['else'] then
                return { type = 'format', id = t[1], if_value = t['if'], else_value = t['else'] }
            elseif t['if'] then
                return { type = 'format', id = t[1], if_value = t['if'] }
            elseif t['else'] then
                return { type = 'format', id = t[1], else_value = t['else'] }
            else
                return { type = 'format', id = t[1] }
            end
        end,

    children = Ct((V('nodes') + V('inner_text'))^0),

    regex = text_clean('/')^1,
    flags = C(R('az', 'AZ')^0), -- Regex flags
    var = C(letter * alnum^0),
    int = C(digit^1) / tonumber,
    replacement = text_clean('$/}')^0 / function(t) return t and t or '' end,
    outer_text = text('$'),
    inner_text = text('$}'),
    choice_text = text_clean(',|'),
    ['if'] = Cg(text('}'), 'if'),
    ['else'] = Cg(text('}'), 'else'),
    modifier = Cg(P('upcase') + P('downcase') + P('capitalize') + P('camelcase') + P('pascalcase'), 'modifier')
}

local snipmate_rules = {
    nodes = (V('tabstop') + V('placeholder') + V('choice') + V('variable') + V('eval') + V('dollar'))^1,

    lang = (P('!') * C(P('lua') + 'l' + 'vim' + 'v') * ws) / function(l)
        return (l == 'lua' or l == 'l') and EvalLang.Lua or EvalLang.Vimscript
    end,

    eval = Ct(P('`') * V('lang')^-1 * text('`') * '`') / function(t)
        if #t == 1 then
            return { type = 'eval', lang = EvalLang.Vimscript, children = { t[1] } }
        else
            return { type = 'eval', lang = t[1], children = { t[2] } }
        end
    end,

    -- No special values in the replacement format
    replacement = text('/}'),

    -- Account for backticks in inner/outer text
    outer_text = text('$`'),
    inner_text = text('$}`'),

    -- For compatibility with some vim-snippets snippets
    dollar = C(P('$')),

    format = P(false), -- No format
}

-- stylua: ignore end

local lsp_grammar = P(base_rules)
local snipmate_grammar = P(vim.tbl_extend('force', base_rules, snipmate_rules))

local function parse(content, pos, grammar)
    local result = grammar:match(content, pos)
    if result then
        return true, result, #content + 1
    end
    return false
end

local M = {}

function M.parse(content, pos)
    return parse(content, pos, lsp_grammar)
end

function M.parse_snipmate(content, pos)
    return parse(content, pos, snipmate_grammar)
end

return M
