" File: autoload/deoplete/snippy.vim
" Description: Helper functions for deoplete. Copied from deoplete-snipmate.


func! deoplete#snippy#get_completion_item(user_data) abort
    if has_key(a:user_data, 'lspitem')
        " deoplete-lsp
        return a:user_data.lspitem
    elseif has_key(a:user_data, 'nvim')
        " nvim-lsp
        try
            return a:user_data.nvim.lsp.completion_item
        catch /^Vim\%((\a\+)\)\=:E716/
        endtry
    endif
    return {}
endfunc

func! deoplete#snippy#try_expand() abort
    let s:snippet_data = {}
    let l:user_data = get(v:completed_item, 'user_data', {})
    let l:snippet = ''
    let l:version = 1
    if !empty(user_data)
        if type(user_data) != v:t_dict
            silent! let user_data = json_decode(user_data)
        endif

        if type(user_data) != v:t_dict
            return
        endif

        let lspitem = deoplete#snippy#get_completion_item(user_data)
        if has_key(user_data, 'snippy')
            let snippet = user_data.snippy.snippet
        else
            if has_key(lspitem, 'textEdit') && type(lspitem.textEdit) == v:t_dict
                let snippet = lspitem.textEdit.newText
            elseif get(lspitem, 'insertTextFormat', -1) == 2
                let snippet = get(lspitem, 'insertText', '')
            endif
        endif

        if empty(snippet)
            return
        endif

        let l:word = v:completed_item['word']

        call v:lua.snippy.expand_snippet(l:snippet, l:word)
    endif
endfunc
