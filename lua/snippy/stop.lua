local shared = require('snippy.shared')

local api = vim.api
local fn = vim.fn

local Stop = {}

function Stop.new(o)
    local self = setmetatable(o, {
        __index = Stop,
        id = -1,
        mark = nil,
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
    return nil
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
    local current_line = fn.getline(from[1] + 1)
    local pre = current_line:sub(1, from[2])
    return pre
end

return Stop
