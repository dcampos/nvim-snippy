local fn = vim.fn
local api = vim.api
local shared = require('snippy.shared')
local util = require('snippy.util')

local M = {}

local exprs = {
    '%s.snippets',
    '%s_*.snippets',
    '%s/*.snippets',
    '%s/*.snippet',
    '%s/*/*.snippet',
}

-- Loading

local function parse_options(prefix, line)
    local opt = line:match(' (%w+)$') or ''
    local word = opt:find('w') and true
    local inword = opt:find('i') and true
    local beginning = opt:find('b') and true
    local auto = opt:find('A') and true

    local custom = {}
    local invalid = false
    for sym in opt:gmatch('[^bwiA]') do
        if not shared.config.expand_options[sym] then
            error(string.format('Unknown option %s in snippet %s', sym, prefix))
        else
            custom[sym] = shared.config.expand_options[sym]
        end
    end

    assert(
        not ((word and inword) or (word and beginning) or (inword and beginning)),
        'Options [w, i, b] cannot be combined'
    )

    return {
        word = word,
        inword = inword,
        beginning = beginning,
        auto_trigger = auto,
        custom = custom,
    }
end

local function parse_header(line)
    local parts = vim.split(line, '%s+')
    local prefix = parts[2]
    assert(parts[1] == 'snippet')
    local option = {}
    local description = #parts > 2 and table.concat(vim.list_slice(parts, 3), ' ') or nil
    if description and description:sub(1, 1) == '"' then
        option = description and parse_options(prefix, line) or {}
        description = description:match('^"(.+)"')
    end
    return prefix, description, option
end

local function read_snippets_file(snippets_file)
    local snips = {}
    local extends = {}
    local priority = 0
    local file = io.open(snippets_file)
    local lines = vim.split(file:read('*a'), '\n')
    if lines[#lines] == '' then
        table.remove(lines)
    end
    local i = 1

    local function parse_snippet()
        local line = lines[i]
        local prefix, description, option = parse_header(line)
        assert(prefix, 'prefix is nil: ' .. line .. ', file: ' .. snippets_file)
        if option.auto_trigger and not shared.config.enable_auto then
            local msg = [[[Snippy] Warning: you seem to have autotriggered snippets,]]
                .. [[ but the autotrigger feature isn't enabled in your config.]]
                .. [[ See :help snippy-snippet-options for details.]]
            vim.notify(msg, vim.log.levels.WARN)
        end
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
        if not snips[prefix] or snips[prefix].priority <= priority then
            if #body > 1 and body[#body] == '' then
                body = vim.list_slice(body, 1, #body - 1)
            end
            snips[prefix] = {
                kind = 'snipmate',
                prefix = prefix,
                priority = priority,
                description = description,
                option = option,
                body = body,
            }
        end
    end

    while i <= #lines do
        local line = lines[i]
        if line:sub(1, 7) == 'snippet' then
            parse_snippet()
        elseif line:sub(1, 7) == 'extends' then
            local scopes = vim.split(vim.trim(line:sub(8)), ', *')
            vim.list_extend(extends, scopes)
            i = i + 1
        elseif line:sub(1, 8) == 'priority' then
            local prio = vim.trim(line:sub(9))
            if not prio or not (prio:match('^%-?%d+$') or prio:match('^%+?%d+$')) then
                error(string.format('Invalid priority in file %s, at line %s: <%s>', snippets_file, i, prio))
            end
            priority = assert(tonumber(prio))
            i = i + 1
        elseif line:sub(1, 1) == '#' or vim.trim(line) == '' then
            -- Skip empty lines between snippets or comments
            i = i + 1
        else
            error(string.format('Unrecognized syntax in snippets file %s, at line %s: %s', snippets_file, i, line))
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
            -- Priority for .snippet is always 0
            priority = 0,
            option = {},
            body = body,
        },
    }
end

--- Returns a list of directories containing snippets
---@return string[]
local function list_dirs()
    local snippet_dirs = shared.config.snippet_dirs
    if snippet_dirs then
        -- If the user has snippet_dirs configured, rtp paths are ignored
        snippet_dirs = type(snippet_dirs) == 'string' and vim.split(snippet_dirs, ',') or snippet_dirs
    else
        -- Runtime path snippet directories
        local rtp = table.concat(vim.api.nvim_list_runtime_paths(), ',')
        snippet_dirs = vim.fn.globpath(rtp, 'snippets', 0, true)

        snippet_dirs = vim.tbl_map(util.normalize_path, snippet_dirs)

        -- Put user config dirs at the end for higher priority
        table.sort(snippet_dirs, function(a, b)
            local config_dir = vim.fn.stdpath('config') .. '/'
            return vim.startswith(b, config_dir) and not vim.startswith(a, config_dir)
        end)
    end

    -- Local snippet directory
    local local_dir = shared.config.local_snippet_dir
    if local_dir and fn.isdirectory(local_dir) == 1 then
        table.insert(snippet_dirs, fn.fnamemodify(local_dir, ':p'))
    end

    for key, dir in ipairs(snippet_dirs) do
        snippet_dirs[key] = vim.fn.substitute(dir, '\\\\$', '', 'g')
    end

    return snippet_dirs
end

local function list_files(ftype)
    local all = {}
    local dirs = table.concat(list_dirs(), ',')
    for _, expr in ipairs(exprs) do
        local e = expr:format(ftype)
        local paths = fn.globpath(dirs, e, 0, true)
        all = vim.list_extend(all, paths)
    end
    return vim.tbl_map(util.normalize_path, all)
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
        snips = util.merge_snippets(snips, result)
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
        snips = util.merge_snippets(snips, result)
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
        for _, dir in ipairs(dirs) do
            local paths = fn.globpath(dir, e, 0, true)
            for _, path in ipairs(paths) do
                path = path:sub(#dir)
                for _, pat in ipairs(patterns) do
                    local m = path:match(pat)
                    if m then
                        scopes[m] = true
                        break
                    end
                end
            end
        end
    end
    return vim.tbl_keys(scopes)
end

function M.list_existing_files()
    local files = {}
    local scopes
    if vim.bo.filetype == '' then
        scopes = M.list_available_scopes()
    else
        scopes = shared.get_scopes()
    end
    for _, scope in ipairs(scopes) do
        local scope_files = list_files(scope)
        vim.list_extend(files, scope_files)
    end
    return files
end

function M.read_snippets(scope)
    local snips = load_scope(scope, {})
    return snips
end

return M
