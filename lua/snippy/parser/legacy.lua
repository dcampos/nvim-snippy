-- Note: this is mostly a translation to Lua from Vimscript of the vsnip parser.

local EvalLang = require('snippy.parser.common').EvalLang

local parser = {}

local comb = require('snippy.parser.comb')
local skip = comb.skip
local seq = comb.seq
local one = comb.one
local many = comb.many
local token = comb.token
local map = comb.map
local pattern = comb.pattern
local opt = comb.opt
local lazy = comb.lazy

local trim = (vim and vim.trim) or function(s)
    return string.gsub(s, '^%s*(.-)%s*$', '%1')
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
local bang = token('!')
local space = token(' ')
local empty = token('')

local varname = pattern('^[_a-zA-Z][_a-zA-Z0-9]*')

local int = map(pattern('^[0-9]+'), function(v)
    return tonumber(v)
end)

local text = function(stop, escape)
    return map(skip(stop, escape or ''), function(value)
        return { type = 'text', raw = value[1], escaped = value[2] }
    end)
end

local tabstop, choice, transform

local flags = map(seq(slash, pattern('^[ig]*')), function(value)
    return value[2]
end)

transform = map(seq(slash, text('/', ''), slash, one(text('[%/}]', ''), empty), opt(flags)), function(value)
    return {
        type = 'transform',
        regex = value[2].raw,
        format = value[4] and value[4].raw or '',
        flags = value[5] or '',
    }
end)

tabstop = one(
    map(seq(sigil, int), function(value)
        return { type = 'tabstop', id = value[2], children = {} }
    end),
    map(seq(sigil, open, int, close), function(value)
        return { type = 'tabstop', id = value[3], children = {} }
    end),
    map(seq(sigil, open, int, transform, close), function(value)
        return { type = 'tabstop', id = value[3], transform = value[4], children = {} }
    end)
)

local options = many(map(seq(text('[,|]', ''), opt(comma)), function(value)
    return trim(value[1].escaped)
end))

choice = map(seq(sigil, open, int, bar, options, bar, close), function(value)
    return { type = 'choice', id = value[3], choices = value[5], children = { value[5][1] } }
end)

-- LSP/VSCode parser

local function create_parser()
    local placeholder, variable

    local any = lazy(function()
        return one(tabstop, placeholder, variable, choice)
    end)

    local inner = opt(many(one(any, text('[$}]', ''))))

    placeholder = map(seq(sigil, open, int, colon, inner, close), function(value)
        local children = #value == 6 and value[5] or {}
        return { type = 'placeholder', id = value[3], children = children }
    end)

    variable = one(
        map(seq(sigil, varname), function(value)
            return { type = 'variable', name = value[2], children = {} }
        end),
        map(seq(sigil, open, varname, close), function(value)
            return { type = 'variable', name = value[3], children = {} }
        end),
        map(seq(sigil, open, varname, colon, inner, close), function(value)
            local children = #value == 6 and value[5] or {}
            return { type = 'variable', name = value[3], children = children }
        end),
        map(seq(sigil, open, varname, transform, close), function(value)
            return { type = 'variable', name = value[3], transform = value[4], children = {} }
        end)
    )

    return many(one(any, text('[%$]', '}')))
end

--  SnipMate parser

local function create_snipmate_parser()
    local eval, variable, placeholder, lang

    local any = lazy(function()
        return one(tabstop, placeholder, variable, choice, eval, sigil)
    end)

    local inner = opt(many(one(any, text('[$}`]', ''))))

    placeholder = map(seq(sigil, open, int, colon, inner, close), function(value)
        local children = #value == 6 and value[5] or {}
        return { type = 'placeholder', id = value[3], children = children }
    end)

    variable = one(
        map(seq(sigil, varname), function(value)
            return { type = 'variable', name = value[2], children = {} }
        end),
        map(seq(sigil, open, varname, close), function(value)
            return { type = 'variable', name = value[3], children = {} }
        end),
        map(seq(sigil, open, varname, colon, inner, close), function(value)
            local children = #value == 6 and value[5] or {}
            return { type = 'variable', name = value[3], children = children }
        end),
        map(seq(sigil, open, varname, transform, close), function(value)
            return { type = 'variable', name = value[3], transform = value[4], children = {} }
        end)
    )

    lang = map(seq(bang, one(token('vim'), token('lua'), token('v'), token('l')), space), function(value)
        if value[2] == 'l' or value[2] == 'lua' then
            return EvalLang.Lua
        else
            return EvalLang.Vimscript
        end
    end)

    eval = map(seq(backtick, one(lang, empty), text('`'), backtick), function(value)
        return {
            type = 'eval',
            children = { value[3] },
            lang = value[2] ~= '' and value[2] or EvalLang.Vimscript,
        }
    end)

    return many(one(any, text('[%$`]', '}')))
end

parser.parse = create_parser()
parser.parse_snipmate = create_snipmate_parser()

return parser
