-- Util

local api = vim.api
local cmd = vim.cmd

local M = {}

function M.print_error(...)
    api.nvim_err_writeln(table.concat(vim.tbl_flatten({ ... }), ' '))
    cmd('redraw')
end

function M.is_after(pos1, pos2)
    return pos1[1] > pos2[1] or (pos1[1] == pos2[1] and pos1[2] > pos2[2])
end

function M.is_before(pos1, pos2)
    return pos1[1] < pos2[1] or (pos1[1] == pos2[1] and pos1[2] < pos2[2])
end

function M.t(input)
    return api.nvim_replace_termcodes(input, true, false, true)
end

function M.normalize_path(path)
    path = vim.fs and vim.fs.normalize(path) or vim.fn.fnamemodify(path, ':p:gs?/\\+?/?')
    return path
end

function M.parse_comment_string()
    local defaults = {
        ['start'] = '/*',
        ['end'] = '*/',
        ['line'] = '//',
    }
    local commentstr = vim.bo.commentstring
    local parts = vim.split(commentstr, '%s-%%s%s-')
    if not parts then
        return defaults
    elseif parts[2] == '' then
        defaults['line'] = parts[1]
    else
        defaults['start'] = parts[1]
        defaults['end'] = parts[2]
    end
    return defaults
end

function M.merge_snippets(current, added)
    local result = vim.deepcopy(current)
    for key, val in pairs(added) do
        if current[key] then
            local cur_snip = current[key]
            local new_snip = added[key]
            if new_snip.priority >= cur_snip.priority then
                result[key] = val
            end
        else
            result[key] = val
        end
    end
    return result
end

function M.validate(rules)
    -- Use vim.validade(table) if neovim >= 0.11, or the new form if not available
    if vim.fn.has('nvim-0.11') == 0 then
        for key, value in rules do
            vim.validate(key, value[1], value[2])
        end
    else
        vim.validate(rules)
    end
end

---Normalizes user-added snippets
---@param snippets table A table containing `{ scope = snippets }` definitions
---@param opts table? Currently only priority can be passed
---@return table
function M.normalize_snippets(snippets, opts)
    M.validate({ snippets = { snippets, 'table' } })
    M.validate({ opts = { opts, 'table', true }, })

    opts = opts or {}

    for trigger, snippet in pairs(snippets) do
        M.validate({
            trigger = { trigger, 'string' },
            snippet = { snippet, { 'string', 'table' } },
        })
        if type(snippet) == 'table' then
            M.validate({
                body = { snippet.body, { 'string', 'table' } },
                priority = { snippet.priority, 'number', true },
                kind = { snippet.kind, 'sring', true },
                opts = { snippet.priority, 'table', true },
            })
        else
            -- Text snippets - add defaults
            snippet = {
                trigger = trigger,
                body = snippet,
            }
        end
        snippet.kind = snippet.kind or 'snipmate'
        snippet.priority = snippet.priority or opts.priority or 999
        snippets[trigger] = snippet
    end

    return snippets
end

function M.expand_virtual_marker(marker_text, number)
    -- Use %n to insert the stop number
    local result = marker_text:gsub('([^%%]-)%%n', '%1' .. number)
    result = result:gsub('%%%%', '%')
    return result
end

---Converts spaces to tabs based on shiftwidth
---@param lines table
---@return table
function M.normalize_indent(lines)
    local leading = ''
    for i, line in ipairs(lines) do
        if i == 1 then
            leading = line:match('^%s*')
        end

        -- Remove leading spaces from all lines
        line = line:gsub('^' .. leading, '')

        lines[i] = line:gsub('^%s+', function(spaces)
            local sw = vim.fn.shiftwidth()
            local tabs = math.floor(#spaces / sw)
            return string.rep('\t', tabs) .. spaces:sub(tabs * sw + 1)
        end)
    end
    return lines
end

return M
