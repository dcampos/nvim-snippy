if vim.g.loaded_snippy or vim.fn.has('nvim') ~= 1 then
    return
end

if vim.fn.has('nvim-0.7.0') == 0 then
  vim.api.nvim_err_writeln('Snippy requires at least nvim-0.7.0')
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
    if (vim.fn.empty(params.args)) then
        local slash = vim.fn.exists("+shellslash") == 1 and '\\' or '/'
        local path = vim.fn.stdpath("config") .. slash .. snippets
        if (not (vim.uv or vim.loop).fs_stat(path)) then
            vim.fn.mkdir(path, 'p')
        end
        local file = path .. slash .. vim.bo.ft .. ".snippets"
        vim.cmd(params.mods .. [[ split ]] .. vim.fn.fnameescape(file))
    else
        vim.cmd(params.mods .. [[ split ]] .. vim.fn.fnameescape(params.args))
    end
end, { nargs = '?', complete = complete_snippet_files })

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
