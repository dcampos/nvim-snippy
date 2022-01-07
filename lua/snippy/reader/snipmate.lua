local fn = vim.fn
local shared = require('snippy.shared')

local M = {}

local exprs = {
    '%s.snippets',
    '%s_*.snippets',
    '%s/*.snippets',
    '%s/*.snippet',
    '%s/*/*.snippet',
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
        local description = line:match('%s*"(.+)"%s*')
        local option = line:match('[bwi]?$') -- Allow at most one option
        local body = {}
        local indent = nil
        i = i + 1
        while i <= #lines do
            line = lines[i]
            if line:find('^%s+') then
                if not indent and line ~= '' then
                    indent = line:match('%s+')
                end
                line = line:sub(#indent + 1)
                line = line:gsub('^' .. indent .. '+', function(m)
                    return string.rep('\t', #m / #indent)
                end)
                table.insert(body, line)
                i = i + 1
            elseif line == '' then
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
            option = option,
            body = body,
        }
    end

    while i <= #lines do
        local line = lines[i]
        if line:sub(1, 7) == 'snippet' then
            parse_snippet()
        elseif line:sub(1, 7) == 'extends' then
            local scopes = vim.split(vim.trim(line:sub(8)), '%s+')
            vim.list_extend(extends, scopes)
            i = i + 1
        elseif line:sub(1, 1) == '#' or vim.trim(line) == '' then
            -- Skip empty lines or comments
            i = i + 1
        else
            error(string.format('Invalid line in snippets file %s: %s', snippets_file, line))
        end
    end
    return snips, extends
end

local function read_snippet_file(snippet_file, scope)
    local description, prefix
    if snippet_file:match('/' .. scope .. '/.-/.*%.snippet$') then
        prefix = fn.fnamemodify(snippet_file, ':h:t')
        description = fn.fnamemodify(snippet_file, ':t:r')
    else
        prefix = fn.fnamemodify(snippet_file, ':t:r')
    end
    local file = io.open(snippet_file)
    local body = vim.split(file:read('*a'), '\n')
    if body[#body] == '' then
        body = vim.list_slice(body, 1, #body - 1)
    end
    return {
        [prefix] = {
            kind = 'snipmate',
            prefix = prefix,
            description = description,
            body = body,
        },
    }
end

local function list_dirs()
    local dirs = shared.config.snippet_dirs
    if not dirs then
        local rtp = table.concat(vim.api.nvim_list_runtime_paths(), ',')
        dirs = vim.fn.globpath(rtp, 'snippets/', 0, 1)
    end
    if type(dirs) ~= 'string' then
        dirs = table.concat(dirs, ',')
    end
    return dirs
end

local function list_files(ftype)
    local all = {}
    local dirs = list_dirs()
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
    for _, file in ipairs(list_files(scope)) do
        local result = {}
        local extended
        if file:match('.snippets$') then
            result, extended = read_snippets_file(file)
            extends = vim.list_extend(extends, extended)
        elseif file:match('.snippet$') then
            result = read_snippet_file(file, scope)
        end
        snips = vim.tbl_extend('force', snips, result)
    end
    for _, extended in ipairs(extends) do
        if vim.tbl_contains(stack, extended) then
            error(
                string.format(
                    'Recursive dependency found: %s',
                    table.concat(vim.tbl_flatten({ stack, extended }), ' -> ')
                )
            )
        end
        local result = load_scope(extended, vim.tbl_flatten({ stack, scope }))
        snips = vim.tbl_extend('keep', snips, result)
    end
    return snips
end

function M.list_available_scopes()
    local dirs = list_dirs()
    local patterns = {
        '/(.-)/.-%.snippets',
        '/(.-)/.-%.snippet',
        '/(_).-%.snippets',
        '/(.-)_.-%.snippets',
        '/(.-)%.snippets',
        '/(.-)%.snippet',
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

function M.list_existing_files()
    local files = {}
    local get_scopes = shared.get_scopes
    for _, scope in ipairs(get_scopes()) do
        local scope_files = list_files(scope)
        vim.list_extend(files, scope_files)
    end
    return files
end

function M.read_snippets()
    local snips = {}
    local get_scopes = shared.get_scopes
    for _, scope in ipairs(get_scopes()) do
        if scope and scope ~= '' then
            snips[scope] = shared.cache[scope]
            if not snips[scope] then
                snips[scope] = load_scope(scope, {})
                shared.cache[scope] = snips[scope]
            end
        end
    end
    return snips
end

return M
