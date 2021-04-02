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

local inspect = (vim and vim.inspect) or require 'inspect'
local trim = (vim and vim.trim) or function (s)
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

-- local i = vim.inpsect

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

--[[
print('--- regex 1')
local ok, result, pos = regex('foo/', 1)
print(i(ok), i(result), i(pos))
]]

local tabstop, placeholder, variable, choice, eval

local any = lazy(function() return
    one(tabstop, placeholder, variable, choice, eval)
end)

local transform = map(
    seq(slash, text('/', ''), slash, text('/', ''), slash, pattern('^[ig]*')),
    function (value)
        return {
            type = 'transform',
            regex = value[2],
            format = value[4],
            flags = value[6]
        }
    end
)

--[[
print('--- transform 1')
ok, result, pos = transform('/foo/bar/i', 1)
print(i(ok), i(result), i(pos))
]]


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

--[[
local ok, result, pos = tabstop('$1', 1)
print(i(ok), i(result), i(pos))
print('--- tabstop 1')
ok, result, pos = tabstop('${2}', 1)
print(i(ok), i(result), i(pos))
print('--- tabstop 2')
ok, result, pos = tabstop('${1/foo/bar/g}', 1)
print(i(ok), i(result), i(pos))
print('--- tabstop 3')
ok, result, pos = tabstop('${1/foo/bar/}', 1)
print(i(ok), i(result), i(pos))
print('--- tabstop 4 - invalid')
ok, result, pos = tabstop('${1:foo}', 1)
print(i(ok), i(result), i(pos))
]]

local inner = many(one(any, text('[$}`]', '')))

placeholder = map(seq(sigil, open, int, colon, inner, close),
    function (value)
        return {type = 'placeholder', id = value[3], children = value[5]}
    end
)

--[[
print('--- any')
ok, result, pos = any('${1}', 1)
print(i(ok), i(result), i(pos))
print('--- placeholder 1')
ok, result, pos = placeholder('${1:foo}', 1)
print(i(ok), i(result), i(pos))
print('--- placeholder 2')
ok, result, pos = placeholder('${1:${2}}', 1)
print(i(ok), i(result), i(pos))
-]]

variable = one(
    map(seq(sigil, varname), function (value)
        return {type = 'variable', name = value[2], children = {}}
    end),
    map(seq(sigil, open, varname, close), function (value)
        return {type = 'variable', name = value[3], children = {}}
    end),
    map(seq(sigil, open, varname, colon, inner, close), function (value)
        return {type = 'variable', name = value[3], children = value[5]}
    end)
)

--[[
print('--- var 1')
ok, result, pos = variable('$TM_SELECTED_TEXT', 1)
print(i(ok), i(result), i(pos))
print('--- var 2')
ok, result, pos = variable('${TM_SELECTED_TEXT}', 1)
print(i(ok), i(result), i(pos))
print('--- var 3')
ok, result, pos = variable('${TM_SELECTED_TEXT:foo bar}', 1)
print(i(ok), i(result), i(pos))
print('--- var 4')
ok, result, pos = variable('${TM_SELECTED_TEXT:${1:foo}}', 1)
print(i(ok), i(result), i(pos))
--]]

local options = many(map(seq(text('[,|]', ''), opt(comma)), function (value)
    return trim(value[1].escaped)
end))

choice = map(seq(sigil, open, int, bar, options, bar, close), function (value)
    return {type = 'choice', id = value[3], choices = value[5], children = {value[5][1]}}
end)

--[[
print('--- choice 1')
ok, result, pos = choice('${1|foo|}', 1)
print(i(ok), i(result), i(pos))
print('--- choice 2')
ok, result, pos = choice('${1|foo,bar,baz|}', 1)
print(i(ok), i(result), i(pos))
--]]

eval = map(seq(backtick, text('`', ''), backtick), function (value)
    return {type = 'eval', children = {value[2]}}
end)

--[[
print('--- eval 1')
ok, result, pos = any('`g:snips_author`', 1)
print(i(ok), i(result), i(pos))
]]

local parse = many(one(any, text('[%$`]', '}')))

--[[
print('--- parser 1')
ok, result, pos = parse('for ${1:value} in ${2:table} do print(${1}) end', 1)
print(i(ok), i(result), i(pos))
print('--- parser 2')
ok, result, pos = parse('foreach (\\$${1:array} as \\$${2:value}) { echo ${1}; }', 1)
print(i(ok), i(result), i(pos))
]]

return {
    parse = parse
}
