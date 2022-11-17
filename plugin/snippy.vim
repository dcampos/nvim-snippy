if exists('g:loaded_snippy') || !has('nvim')
    finish
endif
let g:loaded_snippy = 1

" Navigational mappings
inoremap <silent> <plug>(snippy-expand-or-advance) <cmd>lua require 'snippy'.expand_or_advance()<cr>
imap <silent> <plug>(snippy-expand-or-next) <plug>(snippy-expand-or-advance)
inoremap <silent> <plug>(snippy-expand) <cmd>lua require 'snippy'.expand()<cr>
inoremap <silent> <plug>(snippy-next) <cmd>lua require 'snippy'.next()<cr>
inoremap <silent> <plug>(snippy-previous) <cmd>lua require 'snippy'.previous()<cr>

snoremap <silent> <plug>(snippy-expand-or-advance) <cmd>lua require 'snippy'.expand_or_advance()<cr>
smap <silent> <plug>(snippy-expand-or-next) <plug>(snippy-expand-or-advance)
snoremap <silent> <plug>(snippy-next) <cmd>lua require 'snippy'.next()<cr>
snoremap <silent> <plug>(snippy-previous) <cmd>lua require 'snippy'.previous()<cr>

" Selecting/cutting text
nnoremap <silent> <plug>(snippy-cut-text) <cmd>set operatorfunc=snippy#cut_text<cr>g@
xnoremap <silent> <plug>(snippy-cut-text) <cmd>call snippy#cut_text(mode(), v:true)<cr>

" Commands
command! -nargs=1 -complete=customlist,s:complete_snippet_files
            \ SnippyEdit execute "split" fnameescape(<q-args>)
command! SnippyReload lua require 'snippy'.clear_cache()

function! s:complete_snippet_files(lead, line, curpos) abort
    return luaeval('require("snippy").complete_snippet_files(_A)', a:lead)
endfunction

augroup Snippy
    autocmd!
    autocmd BufWritePost *.snippet{,s} lua require 'snippy.main'.clear_cache()
    autocmd OptionSet *runtimepath* lua require 'snippy.main'.clear_cache()
augroup END
