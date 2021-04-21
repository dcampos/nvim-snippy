local fn = vim.fn
local shared = require 'snippy.shared'

local M = {}

local exprs = {
    'snippets/%s.snippets',
    'snippets/%s_*.snippets',
    'snippets/%s/*.snippets',
    'snippets/%s/*.snippet',
    'snippets/%s/*/*.snippet',
}

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

    local function parse_snippet()
        local line = lines[i]
        local prefix = line:match('%s+(%S+)%s*')
        assert(prefix, 'prefix is nil: ' .. line .. ', file: ' .. snippets_file)
        local description = line:match('%s*"(.+)"%s*$')
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
        snips[prefix] = {
            kind = 'snipmate',
            prefix = prefix,
            description = description,
            body = body
        }
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
    return {
        [prefix] = {
            kind = 'snipmate',
            prefix = prefix,
            description = description,
            body = body
        }
    }
end

local function list_dirs(ftype)
    local all = {}
    local dirs = shared.config.snippet_dirs or vim.o.rtp
    for _, expr in ipairs(exprs) do
        local e = expr:format(ftype)
        local paths = fn.globpath(dirs, e, 0, 1)
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

function M.list_available_scopes()
    local dirs = shared.config.snippet_dirs or vim.o.rtp
    local patterns = {
        '/snippets/(.-)/.-%.snippets',
        '/snippets/(.-)/.-%.snippet',
        '/snippets/(_).-%.snippets',
        '/snippets/(.-)_.-%.snippets',
        '/snippets/(.-)%.snippets',
        '/snippets/(.-)%.snippet'
    }
    local scopes = {}
    for _, expr in ipairs(exprs) do
        local e = expr:format('*')
        local paths = fn.globpath(dirs, e, 0, 1)
        for _, path in ipairs(paths) do
            for _, pat in ipairs(patterns) do
                local m = path:match(pat)
                if m then
                    scopes[m] = true
                    break
                end
            end
        end
    end
    return vim.tbl_keys(scopes)
end

function M.read_snippets()
    local snips = {}
    local get_scopes = shared.config.get_scopes
    for _, scope in ipairs(get_scopes()) do
        if scope and scope ~= '' then
            snips[scope] = load_scope(scope, {})
        end
    end
    return snips
end

return M
