local shared = require('snippy.shared')
local util = require('snippy.util')

local api = vim.api
local fn = vim.fn

---@class Stop
---@field id number
---@field order number
---@field traversable boolean
---@field mark number
---@field spec table
local Stop = {}

function Stop.new(o)
    local self = setmetatable(o, {
        __index = Stop,
        id = -1,
        order = -1,
        traversable = false,
        mark = nil,
        spec = {},
    })
    return self
end

function Stop:get_range()
    local mark = api.nvim_buf_get_extmark_by_id(0, shared.namespace, self.mark, { details = true })
    if #mark > 0 then
        local startrow, startcol = mark[1], mark[2]
        local endrow, endcol = mark[3].end_row, mark[3].end_col
        return { startrow, startcol }, { endrow, endcol }
    end
    error('No mark found for stop')
end

function Stop:get_text()
    local startpos, endpos = self:get_range()
    local lines = api.nvim_buf_get_lines(0, startpos[1], endpos[1] + 1, false)
    lines[#lines] = lines[#lines]:sub(1, endpos[2])
    lines[1] = lines[1]:sub(startpos[2] + 1)
    return table.concat(lines, '\n')
end

function Stop:set_text(text)
    local startpos, endpos = self:get_range()
    if self.spec.transform then
        local transform = self.spec.transform
        text = fn.substitute(text, transform.regex, transform.format, transform.flags)
    end
    local lines = vim.split(text, '\n', true)
    api.nvim_buf_set_text(0, startpos[1], startpos[2], endpos[1], endpos[2], lines)
end

function Stop:get_before()
    local from, _ = self:get_range()
    assert(from, 'from should not be nil')
    local current_line = fn.getline(from[1] + 1)
    local pre = current_line:sub(1, from[2])
    return pre
end

function Stop:get_children()
    local buf = require('snippy.buf')
    for n, stop in ipairs(buf.state().stops) do
        if self.id == stop.spec.parent then
            return vim.list_extend({ n }, stop:get_children())
        end
    end
    return {}
end

function Stop:get_parents()
    local buf = require('snippy.buf')
    if not self.spec.parent then
        return {}
    end
    for n, stop in ipairs(buf.state().stops) do
        if stop.id == self.spec.parent and stop.spec.type == 'placeholder' then
            return vim.list_extend({ n }, stop:get_parents())
        end
    end
    return {}
end

function Stop:is_inside(other)
    local ostartpos, oendpos = other:get_range()
    local startpos, endpos = self:get_range()
    if ostartpos == nil or oendpos == nil or startpos == nil or endpos == nil then
        return false
    end
    local startposcheck = ostartpos[1] == startpos[1] and ostartpos[2] == startpos[2]
    local endposcheck = oendpos[1] == endpos[1] and oendpos[2] == endpos[2]
    return (startposcheck or util.is_before(ostartpos, startpos) and (endposcheck or util.is_after(oendpos, endpos)))
end

return Stop
