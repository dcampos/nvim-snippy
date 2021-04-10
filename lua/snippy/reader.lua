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

function M.read_snips()
    local snips = {}
    for _,file in ipairs(fn.globpath(vim.o.rtp, 'snippets/*.snippets', 0, 1)) do
        local ftype_snips = read_snippets_file(file)
        local ftype = fn.fnamemodify(file, ':t:r')
        snips[ftype] = ftype_snips
    end
    return snips
end

return M
