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

function M.expand_virtual_marker(marker_text, number)
    -- Use %n to insert the stop number
    local result = marker_text:gsub('([^%%]-)%%n', '%1' .. number)
    result = result:gsub('%%%%', '%')
    return result
end

return M
