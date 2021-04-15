local fn = vim.fn
local config = require 'snippy.config'

local M = {}

-- Loading

local function read_snippets_file(snippets_file)
    local snips = {}
    local extends = {}
    local file = io.open(snippets_file)
    local lines = vim.split(file:read('*a'), '\n')
    if lines[#lines] == '' then
        table.remove(lines)
    end
    local i = 1

    -- print('> parsing file:', snippets_file)

    local function parse_snippet()
        local line = lines[i]
        local prefix = line:match(' +(%S+) *')
        local description = line:match(' *"(.+)" *$')
        local body = {}
        i = i + 1
        while i <= #lines do
            line = lines[i]
            if line:sub(1, 1) == '\t' or line == '' then
                -- print('> line =', line)
                line = line:sub(2)
                table.insert(body, line)
                i = i + 1
            else
                break
            end
        end
        snips[prefix] = {prefix=prefix, description = description, body = body}
    end

    while i <= #lines do
        local line = lines[i]
        if line:sub(1, 7) == 'snippet' then
            -- print('> parsing snippet - line:', line)
            parse_snippet()
        elseif line:sub(1, 7) == 'extends' then
            -- print('> extends found', i, line)
            local scopes = vim.split(vim.trim(line:sub(8)), '%s+')
            vim.list_extend(extends, scopes)
            i = i + 1
        elseif line:sub(1, 1) == '#' or vim.trim(line) == '' then
            -- Skip empty lines or comments
            i = i + 1
        else
            error(string.format("Invalid line in snippets file %s: %s", snippets_file, line))
        end
    end
    return snips, extends
end

local function read_snippet_file(snippet_file)
    local description, prefix
    if snippet_file:match('snippets/.-/.-/.*%.snippet$') then
        prefix = fn.fnamemodify(snippet_file, ':h:t')
        description = fn.fnamemodify(snippet_file, ':t:r')
    else
        prefix = fn.fnamemodify(snippet_file, ':t:r')
    end
    local file = io.open(snippet_file)
    local body = vim.split(file:read('*a'), '\n')
    return {[prefix] = {prefix = prefix, description = description, body = body}}
end

local function list_dirs(ftype)
    local all = {}
    local dirs = config.snippet_dirs or vim.o.rtp
    local exprs = {
        'snippets/'.. ftype ..'.snippets',
        'snippets/'.. ftype ..'_*.snippets',
        'snippets/'.. ftype ..'/*.snippets',
        'snippets/'.. ftype ..'/*.snippet',
        'snippets/'.. ftype ..'/*/*.snippet',
    }
    for _, expr in ipairs(exprs) do
        local paths = fn.globpath(dirs, expr, 0, 1)
        all = vim.list_extend(all, paths)
    end
    return all
end

local function load_scope(scope, stack)
    local snips = {}
    local extends = {}
    for _, file in ipairs(list_dirs(scope)) do
        local result = {}
        local extended = {}
        if file:match('.snippets$') then
            result, extended = read_snippets_file(file)
            extends = vim.list_extend(extends, extended)
        elseif file:match('.snippet$') then
            result = read_snippet_file(file)
        end
        snips = vim.tbl_extend('force', snips, result)
    end
    for _, extended in ipairs(extends) do
        if vim.tbl_contains(stack, extended) then
            error(string.format('Recursive dependency found: %s',
                table.concat(vim.tbl_flatten({stack, extended}), ' -> ')))
        end
        local result = load_scope(extended, vim.tbl_flatten({stack, scope}))
        snips = vim.tbl_extend('keep', snips, result)
    end
    return snips
end

function M.read_snippets()
    local snips = {}
    local get_scopes = config.get_scopes
    for _, scope in ipairs(get_scopes()) do
        if scope and scope ~= '' then
            snips[scope] = load_scope(scope, {})
        end
    end
    return snips
end

return M
