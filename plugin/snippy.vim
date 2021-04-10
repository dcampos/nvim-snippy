lua snippy = require("snippy")

inoremap <silent> <Plug>(snippy-expand-or-advance) <Esc>:lua return snippy.expand_or_advance()<CR>
inoremap <silent> <Plug>(snippy-expand) <Esc>:lua return snippy.expand()<CR>
inoremap <silent> <Plug>(snippy-next-stop) <Esc>:lua return snippy.next_stop()<CR>
snoremap <silent> <Plug>(snippy-next-stop) <Esc>:<C-u>lua return snippy.next_stop()<CR>
inoremap <silent> <Plug>(snippy-previous-stop) <Esc>:lua return snippy.previous_stop()<CR>
snoremap <silent> <Plug>(snippy-previous-stop) <Esc>:<C-u>lua return snippy.previous_stop()<CR>
