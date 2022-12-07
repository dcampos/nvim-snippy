if vim.g.loaded_snippy or vim.fn.has('nvim') ~= 1 then
    return
end

vim.g.loaded_snippy = true

local map = vim.keymap.set

-- Navigational mappings
map('i', '<plug>(snippy-expand-or-next)', '<plug>(snippy-expand-or-advance)', { remap = true })
map('i', '<plug>(snippy-expand-or-advance)', '<cmd>lua require "snippy".expand_or_advance()<cr>')
map('i', '<plug>(snippy-expand)', '<cmd>lua require "snippy".expand()<cr>')
map('i', '<plug>(snippy-next)', '<cmd>lua require "snippy".next()<cr>')
map('i', '<plug>(snippy-previous)', '<cmd>lua require "snippy".previous()<cr>')

map('s', '<plug>(snippy-expand-or-next)', '<plug>(snippy-expand-or-advance)', { remap = true })
map('s', '<plug>(snippy-expand-or-advance)', '<cmd>lua require "snippy".expand_or_advance()<cr>')
map('s', '<plug>(snippy-next)', '<cmd>lua require "snippy".next()<cr>')
map('s', '<plug>(snippy-previous)', '<cmd>lua require "snippy".previous()<cr>')

-- Selecting/cutting text
map('n', '<plug>(snippy-cut-text)', '<cmd>set operatorfunc=snippy#cut_text<cr>g@')
map('x', '<plug>(snippy-cut-text)', '<cmd>call snippy#cut_text(mode(), v:true)<cr>')

local command = vim.api.nvim_create_user_command

local function complete_snippet_files(lead, _, _)
    return require('snippy').complete_snippet_files(lead)
end

command('SnippyEdit', function(params)
    vim.cmd([[split ]] .. vim.fn.fnameescape(params.args))
end, { nargs = 1, complete = complete_snippet_files })

command('SnippyReload', function()
    require('snippy').clear_cache()
end, {})

local group = vim.api.nvim_create_augroup('Snippy', {})

vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.snippet{,s}',
    callback = function()
        require('snippy.main').clear_cache()
    end,
})

vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = '*runtimepath*',
    callback = function()
        require('snippy.main').clear_cache()
    end,
})
