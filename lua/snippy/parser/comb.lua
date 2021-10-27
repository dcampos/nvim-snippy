-- Note: this is mostly a translation to Lua from Vimscript of the vsnip combinators.

local function skip(stop, escape)
    return function(text, apos)
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
                        return true, { text:sub(apos, pos - 1), value }, pos
                    else
                        return false, nil, pos
                    end
                end

                value = value .. char
                pos = pos + 1
            end
        end
        return true, { text:sub(apos), value }, #text + 1
    end
end

local function seq(...)
    local parsers = { ... }
    return function(text, apos)
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
    return function(text, apos)
        if text:sub(apos, apos + #value - 1) == value then
            return true, value, apos + #value
        else
            return false, nil, apos
        end
    end
end

local function many(parser)
    return function(text, apos)
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
    local parsers = { ... }
    return function(text, apos)
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
    return function(text, pos)
        local from, to = text:find(pat, pos)
        if from then
            local s = text:sub(from, to)
            return true, s, pos + #s
        end
        return false, nil, pos
    end
end

local function opt(parser)
    return function(text, pos)
        local ok, value, _pos = parser(text, pos)
        if ok then
            return ok, value, _pos
        end
        return true, nil, pos
    end
end

local function map(parser, func)
    return function(text, pos)
        local ok, value, _pos = parser(text, pos)
        if ok then
            return true, func(value), _pos
        end
        return ok, value, _pos
    end
end

local function lazy(func)
    return function(text, pos)
        return func()(text, pos)
    end
end

return {
    skip = skip,
    token = token,
    seq = seq,
    many = many,
    one = one,
    pattern = pattern,
    lazy = lazy,
    map = map,
    opt = opt,
}
