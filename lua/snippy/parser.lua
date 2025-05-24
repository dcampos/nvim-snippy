if vim.fn.has('nvim-0.10') == 1 then
    return require('snippy.parser.lpeg')
else
    return require('snippy.parser.legacy')
end
