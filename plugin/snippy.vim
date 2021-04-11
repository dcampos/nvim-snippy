lua snippy = require("snippy")

inoremap <silent> <Plug>(snippy-expand-or-advance) <cmd>lua snippy.expand_or_advance()<CR>
inoremap <silent> <Plug>(snippy-expand) <cmd>lua snippy.expand()<CR>
inoremap <silent> <Plug>(snippy-next-stop) <cmd>lua snippy.next_stop()<CR>
inoremap <silent> <Plug>(snippy-previous-stop) <cmd>lua snippy.previous_stop()<CR>
snoremap <silent> <Plug>(snippy-next-stop) <cmd>lua snippy.next_stop()<CR>
snoremap <silent> <Plug>(snippy-previous-stop) <cmd>lua snippy.previous_stop()<CR>
