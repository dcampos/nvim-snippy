-- combinators
-- return success, value, pos

local function sym(t)
    return function(text, pos)
        if text:sub(pos, pos + #t - 1) == t then
            return true, nil, pos + #t
        else
            return false, text:sub(pos, pos + #t), pos + #t
        end
    end
end

local function pattern(pat)
    return function(text, pos)
        local s, e = text:find(pat, pos)

        if s then
            local v = text:sub(s, e)
            return true, v, pos + #v
        else
            return false, nil, pos
        end
    end
end

local function map(p, f)
    return function(text, pos)
        local succ, val, new_pos = p(text, pos)
        if succ then
            return true, f(val), new_pos
        end
        return false, nil, pos
    end
end

local function any(...)
    local parsers = { ... }
    return function(text, pos)
        for _, p in ipairs(parsers) do
            local succ, val, new_pos = p(text, pos)
            if succ then
                return true, val, new_pos
            end
        end
        return false, nil, pos
    end
end

local function seq(...)
    local parsers = { ... }
    return function(text, pos)
        local original_pos = pos
        local values = {}
        for _, p in ipairs(parsers) do
            local succ, val, new_pos = p(text, pos)
            pos = new_pos
            if not succ then
                return false, nil, original_pos
            end
            table.insert(values, val)
        end
        return true, values, pos
    end
end

local function many(p)
    return function(text, pos)
        local len = #text
        local values = {}

        while pos <= len do
            local succ, val, new_pos = p(text, pos)
            if succ then
                pos = new_pos
                table.insert(values, val)
            else
                break
            end
        end
        return #values > 0, values, pos
    end
end

local function take_until(patterns)
    return function(text, pos)
        local s, e = text:find(patterns, pos)
        -- TODO: handle escaping

        if s then
            -- would be empty string
            if pos == s then
                return false, nil, pos
            else
                -- consume up to the match point
                return true, text:sub(pos, s - 1), s
            end
        elseif pos <= #text then
            -- no match but there's text to consume
            return true, text:sub(pos), #text + 1
        else
            return false, nil, pos
        end
    end
end

local function separated(sep, p)
    return function(text, pos)
        local len = #text
        local values = {}

        local succ, val, new_pos = p(text, pos)
        if not succ then
            return false, nil, pos
        end
        table.insert(values, val)
        pos = new_pos

        while pos <= len do
            local succ, _, new_pos = sep(text, pos)
            if not succ then
                break
            end
            pos = new_pos


            local succ, val, new_pos = p(text, pos)
            if not succ then
                break
            end

            table.insert(values, val)
            pos = new_pos
        end
        return true, values, pos
    end
end

local function lazy(f)
    return function(text, pos)
        return f()(text, pos)
    end
end

-- parsers

local dollar = sym("$")
local open = sym("{")
local close = sym("}")
local colon = sym(":")
local slash = sym("/")
local comma = sym(",")
local pipe = sym("|")
local backtick = sym("`")

local var = pattern("^[_a-zA-Z][_a-zA-Z0-9]*")

local int = map(pattern("^%d+"), function(v) return tonumber(v) end)

local text = take_until

-- TODO: opt so we can avoid swallowing the close here
local regex = map(
    seq(slash, take_until("/"), slash, take_until("/"), slash, any(take_until("}"), close)),
    function(v) return { type = "regex", value = v[1], format = v[2], options = v[3]} end
)

local tabstop, placeholder, choice, variable, anything, eval

-- need to make lazy so that tabstop/placeholder/variable aren't nil at
-- declaration time because of mutual recursion.
anything = lazy(function() return any(
    tabstop,
    placeholder,
    choice,
    variable,
    eval
    -- -- text: we do this on a per usecase basis
) end)

tabstop = any(
    map(
        any(
            seq(dollar, int),
            seq(dollar, open, int, close)
        ),
        function(v) return { type = "tabstop", id = v[1] } end
    ),
    map(
        seq(dollar, open, int, regex), -- regex already eats the close
        function(v) return { type = "tabstop", id = v[1], regex = v[2] } end
    )
)

placeholder = map(
    -- match until $ or }
    seq(dollar, open, int, colon, many(any(anything, text("[%$}]"))), close),
    function(v) return { type = "placeholder", id = v[1], value = v[2] } end
)

choice = map(
    -- match until , or |
    seq(dollar, open, int, pipe, separated(comma, text("[,|]")), pipe, close),
    function(v) return { type = "choice", id = v[1], value = v[2] } end
)

variable = any(
    map(
        seq(dollar, var),
        function(v) return { type = "variable", name = v[1] } end
    ),
    map(
        seq(dollar, open, var, colon, many(any(anything, text("}"))), close),
        function(v) return { type = "variable", name = v[1], default = v[2] } end
    ),
    map(
        seq(dollar, open, var, regex), -- regex already eats the close
        function(v) return { type = "variable", name = v[1], regex = v[2] } end
    )
)

eval = map(
    seq(backtick, text("`"), backtick),
    function(v) return { type = "eval", value = v[1] } end
)

-- toplevel text matches until $
local parse = many(any(anything, text("[%$`]")))


-- s, v, _ = parse("", 1)
-- s, v, _ = parse("hello $1${2} ${1|one,two,three|} ${name:foo} $var $TM ${TM_FILENAME/(.*).+$/$1/} ${1: $TM_SELECTED_TEXT }", 1)
-- s, v, p = parse("local ${1:var} = ${1:value}", 1)
-- print(s, vim.inspect(v), p)

return { parse = parse }

-- vim:et ts=4 sw=4
