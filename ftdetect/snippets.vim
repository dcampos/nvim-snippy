" Copied and adapted from SnipMate
au BufRead,BufNewFile *.snippet,*.snippets setlocal filetype=snippets

au FileType snippets if expand('<afile>:e') =~# 'snippet$'
            \ | setlocal syntax=snippet
            \ | else
                \ | setlocal syntax=snippets
                \ | endif
