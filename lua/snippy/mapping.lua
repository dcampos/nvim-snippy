local M = {}

local snippy = require('snippy')
local shared = require('snippy.shared')

local api = vim.api

local function feedkey(key)
    if key then
        api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, true, true), 'n', true)
    end
end

M.Expand = 'expand'
M.ExpandOrAdvance = 'expand_or_advance'
M.Next = 'next'
M.Previous = 'previous'
M.CutText = 'cut_text'

M.expand = function(fallback)
    return function()
        if snippy.can_expand() then
            snippy.expand()
        else
            feedkey(fallback)
        end
    end
end

M.expand_or_advance = function(fallback)
    return function()
        if snippy.can_expand_or_advance() then
            snippy.expand_or_advance()
        else
            feedkey(fallback)
        end
    end
end

M.next = function(fallback)
    return function()
        if snippy.can_jump(1) then
            snippy.next()
        else
            feedkey(fallback)
        end
    end
end

M.previous = function(fallback)
    return function()
        if snippy.can_jump(-1) then
            snippy.previous()
        else
            feedkey(fallback)
        end
    end
end

M.cut_text = '<Plug>(snippy-cut-text)'

local function create_rhs(rhs, lhs)
    if type(M[rhs]) == 'function' then
        return '', { callback = M[rhs](lhs), desc = string.format('snippy.%s()', rhs) }
    elseif type(M[rhs]) == 'string' then
        return M[rhs], {}
    end
end

function M.init()
    local mappings = shared.config.mappings
    if not mappings then
        return
    end

    for modes, mapping in pairs(mappings) do
        modes = type(modes) == 'table' and modes or vim.split(modes, '')
        for _, mode in ipairs(modes) do
            for lhs, _rhs in pairs(mapping) do
                local rhs, opt = create_rhs(_rhs, lhs)
                api.nvim_set_keymap(mode, lhs, rhs, opt)
            end
        end
    end
end

return M
