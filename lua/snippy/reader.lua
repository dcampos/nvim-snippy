local fn = vim.fn

local M = {}

-- Loading

local function read_snippets_file(snippets_file)
    local snips = {}
    local current = nil
    local file = io.open(snippets_file)
    local lines = vim.split(file:read('*a'), '\n')
    for _, line in ipairs(lines) do
        if line:sub(1, 7) == 'snippet' then
            local prefix = line:match(' +(%w+) *')
            current = prefix
            local description = line:match(' *"(.+)" *$')
            snips[prefix] = {prefix=prefix, description = description, body = {}}
        elseif line:sub(1,1) ~= '#' then
            local value = line:gsub('^\t', '')
            if current then
                table.insert(snips[current].body, value)
            end
        end
    end
    return snips
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
    local exprs = {
        'snippets/'.. ftype ..'.snippets',
        'snippets/'.. ftype ..'*.snippets',
        'snippets/'.. ftype ..'/*.snippets',
        'snippets/'.. ftype ..'/*.snippet',
        'snippets/'.. ftype ..'/*/*.snippet',
    }
    for _, expr in ipairs(exprs) do
        local paths = fn.globpath(vim.o.rtp, expr, 0, 1)
        all = vim.list_extend(all, paths)
    end
    return all
end

function M.read_snippets(ftype)
    local snips = {}
    for _, file in ipairs(list_dirs(ftype)) do
        local result = {}
        if file:match('.snippets$') then
            result = read_snippets_file(file)
        elseif file:match('.snippet$') then
            result = read_snippet_file(file)
        end
        snips[ftype] = snips[ftype] or {}
        snips[ftype] = vim.tbl_extend('force', snips[ftype], result)
    end
    return snips
end

return M
