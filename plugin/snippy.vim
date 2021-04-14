if exists('g:loaded_snippy') || !has('nvim')
    finish
endif
let g:loaded_snippy = 1

lua snippy = require("snippy")

" Navigational mappings
inoremap <silent> <plug>(snippy-expand-or-advance) <cmd>lua snippy.expand_or_advance()<cr>
inoremap <silent> <plug>(snippy-expand) <cmd>lua snippy.expand()<cr>
inoremap <silent> <plug>(snippy-next-stop) <cmd>lua snippy.next_stop()<cr>
inoremap <silent> <plug>(snippy-previous-stop) <cmd>lua snippy.previous_stop()<cr>
snoremap <silent> <plug>(snippy-next-stop) <cmd>lua snippy.next_stop()<cr>
snoremap <silent> <plug>(snippy-previous-stop) <cmd>lua snippy.previous_stop()<cr>

" Selecting/cutting text
nnoremap <silent> <plug>(snippy-cut-text) <cmd>set operatorfunc=v:lua.snippy.cut_text<cr>g@
xnoremap <silent> <plug>(snippy-cut-text) <cmd>call luaeval('snippy.cut_text(_A, true)', mode())<cr>
