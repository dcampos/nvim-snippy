-- local i = vim.inspect

local function skip(stop, escape)
    return function (text, apos)
        local value = ''
        local pos = apos
        while pos <= #text do
            local char = text:sub(pos, pos)

            if char == '\\' then
                pos = pos + 1
                char = text:sub(pos, pos)
                if not char:match(stop) and not char:match(escape) and char ~= '\\' then
                    value = value .. '\\'
                else
                    pos = pos + 1
                    value = value .. char
                end
            else
                if char:match(stop) then
                    if pos ~= apos then
                        return true, {text:sub(apos, pos - 1), value}, pos
                    else
                        return false, nil, pos
                    end
                end

                value = value .. char
                pos = pos + 1
            end
        end
        return true, {text:sub(apos), value}, #text + 1
    end
end

local function seq(...)
    local parsers = {...}
    return function (text, apos)
        local pos = apos
        local values = {}
        for _, parser in ipairs(parsers) do
            local ok, value, _pos = parser(text, pos)
            if not ok then
                return false, nil, apos
            end
            table.insert(values, value)
            pos = _pos
        end
        return true, values, pos
    end
end

local function token(value)
    return function (text, apos)
        if text:sub(apos, apos + #value - 1) == value then
            return true, value, apos + #value
        else
            return false, nil, apos
        end
    end
end

local function many(parser)
    return function (text, apos)
        local pos = apos
        local values = {}
        while pos <= #text do
            local ok, value, _pos = parser(text, pos)
            if ok then
                table.insert(values, value)
                pos = _pos
            else
                break
            end
        end
        if #values > 0 then
            return true, values, pos
        else
            return false, nil, apos
        end
    end
end

local function one(...)
    local parsers = {...}
    return function (text, apos)
        local pos = apos
        for _, parser in ipairs(parsers) do
            local ok, value, _pos = parser(text, pos)
            if ok then
                return true, value, _pos
            end
        end
        return false, nil, apos
    end
end

local function pattern(pat)
    return function (text, pos)
        local from, to = text:find(pat, pos)
        if from then
            local s = text:sub(from, to)
            return true, s, pos + #s
        end
        return false, nil, pos
    end
end

local function opt(parser)
    return function (text, pos)
        local ok, value, _pos = parser(text, pos)
        if ok then
            return ok, value, _pos
        end
        return true, nil, pos
    end
end

local function map(parser, func)
    return function (text, pos)
        local ok, value, _pos = parser(text, pos)
        if ok then
            return true, func(value), _pos
        end
        return ok, value, _pos
    end
end

local function lazy(func)
    return function (text, pos)
        return func()(text, pos)
    end
end

--[[
local i = vim.inspect
local text = skip('[{}]', '[{}]')
local ok, result, pos = text('foo = {bar}', 1)
print(i(ok), i(result), i(pos))

local escaped = skip('[{}]', '[{}]')
ok, result, pos = escaped("foo = \\{bar\\}", 1)
print(i(ok), i(result), i(pos))

local sigil = token('$')
ok, result, pos = sigil('foo = ${bar}', 7)
print(i(ok), i(result), i(pos))

local lb = token('{')
ok, result, pos = lb('foo = {bar}', 7)
print(i(ok), i(result), i(pos))

local rb = token('}')
ok, result, pos = rb('foo = {bar}', 11)
print(i(ok), i(result), i(pos))

local bracketed = seq(sigil, lb, skip('}', '}'), rb)
ok, result, pos = bracketed('foo = ${bar}', 7)
print(i(ok), i(result), i(pos))

local many_bracketed = many(bracketed)
ok, result, pos = many_bracketed('${foo}${bar}${baz}', 1)
print(i(ok), i(result), i(pos))

local anything = one(text, bracketed, rb, lb)
ok, result, pos = anything('${foo = bar}', 1)
print(i(ok), i(result), i(pos))

local p = pattern('^[a-zA-Z0-9]+')
ok, result, pos = p('snippet foo', 1)
print(i(ok), i(result), i(pos))

local lp = lazy(function() return p end)
ok, result, pos = lp('snippet foo', 1)
print(i(ok), i(result), i(pos))

local mp = lazy(function() return
    map(p, function(v)
        return {value = v}
    end)
end)
ok, result, pos = mp('snippet foo', 1)
print(i(ok), i(result), i(pos))

local o = opt(p)
ok, result, pos = o('', 1)
print(i(ok), i(result), i(pos))
]]


return {
    skip = skip,
    token = token,
    seq = seq,
    many = many,
    one = one,
    pattern = pattern,
    lazy = lazy,
    map = map,
    opt = opt
}
