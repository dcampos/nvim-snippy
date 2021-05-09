-- Note: this is mostly a translation to Lua from Vimscript of the vsnip parser.

local comb = require "snippy.parser.comb"
local skip = comb.skip
local seq = comb.seq
local one = comb.one
local many = comb.many
local token = comb.token
local map = comb.map
local pattern = comb.pattern
local opt = comb.opt
local lazy = comb.lazy

local inspect = vim and vim.inspect or require 'inspect'

local trim = (vim and vim.trim) or function (s)
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

-- Tokens
local sigil = token('$')
local open = token('{')
local close = token('}')
local colon = token(':')
local slash = token('/')
local comma = token(',')
local bar = token('|')
local backtick = token('`')

local varname = pattern('^[_a-zA-Z][_a-zA-Z0-9]*')

local int = map(pattern('^[0-9]+'), function (v)
    return tonumber(v)
end)

local text = function (stop, escape)
    return map(skip(stop, escape), function (value)
        return {type = 'text', raw = value[1], escaped = value[2]}
    end)
end

local tabstop, choice, transform

local flags = map(seq(slash, pattern('^[ig]*')), function (value)
    return value[2]
end)

transform = map(
        seq(slash, text('/', ''), slash, text('[%/}]', ''), opt(flags)),
        function (value)
            return {
                type = 'transform',
                regex = value[2],
                format = value[4],
                flags = value[5] or ''
            }
        end)

tabstop = one(
    map(seq(sigil, int), function (value)
        return {type = 'tabstop', id = value[2], children = {}}
    end),
    map(seq(sigil, open, int, close), function (value)
        return {type = 'tabstop', id = value[3], children = {}}
    end),
    map(seq(sigil, open, int, transform, close), function (value)
        return {type = 'tabstop', id = value[3], transform = value[4], children = {}}
    end)
)

local options = many(map(seq(text('[,|]', ''), opt(comma)), function (value)
    return trim(value[1].escaped)
end))

choice = map(seq(sigil, open, int, bar, options, bar, close), function (value)
    return {type = 'choice', id = value[3], choices = value[5], children = {value[5][1]}}
end)

-- LSP/VSCode parser

local function create_parser()
    local placeholder, variable

    local any = lazy(function() return
        one(tabstop, placeholder, variable, choice)
    end)

    local inner = opt(many(one(any, text('[$}]', ''))))

    placeholder = map(seq(sigil, open, int, colon, inner, close),
        function (value)
            return {type = 'placeholder', id = value[3], children = value[5]}
        end
    )

    variable = one(
        map(seq(sigil, varname), function (value)
            return {type = 'variable', name = value[2], children = {}}
        end),
        map(seq(sigil, open, varname, close), function (value)
            return {type = 'variable', name = value[3], children = {}}
        end),
        map(seq(sigil, open, varname, colon, inner, close), function (value)
            return {type = 'variable', name = value[3], children = value[5]}
        end),
        map(seq(sigil, open, varname, transform, close), function (value)
            return {type = 'variable', name = value[3], transform = value[4], children = {}}
        end)
    )

    return many(one(any, text('[%$]', '}')))
end

--  SnipMate parser

local function create_snipmate_parser()
    local eval, visual, placeholder

    local any = lazy(function() return
        one(tabstop, placeholder, visual, choice, eval, sigil)
    end)

    local inner = opt(many(one(any, text('[$}`]', ''))))

    placeholder = map(seq(sigil, open, int, colon, inner, close),
        function (value)
            return {type = 'placeholder', id = value[3], children = value[5]}
        end
    )

    local visual_token = token('VISUAL')

    visual = one(
        map(seq(sigil, visual_token), function (value)
            return {type = 'variable', name = value[2], children = {}}
        end),
        map(seq(sigil, open, visual_token, close), function (value)
            return {type = 'variable', name = value[3], children = {}}
        end),
        map(seq(sigil, open, visual_token, colon, inner, close), function (value)
            return {type = 'variable', name = value[3], children = value[5]}
        end)
    )

    eval = map(seq(backtick, text('`', ''), backtick), function (value)
        return {type = 'eval', children = {value[2]}}
    end)

    return many(one(any, text('[%$`]', '}')))
end

local parse = create_parser()
local parse_snipmate = create_snipmate_parser()

return {
    parse = parse,
    parse_snipmate = parse_snipmate
}
