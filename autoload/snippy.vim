function! snippy#can_expand() abort
    return luaeval("require 'snippy'.can_expand()")
endfunction

function! snippy#can_expand_or_advance() abort
    return luaeval("require 'snippy'.can_expand_or_advance()")
endfunction

function! snippy#can_jump(direction) abort
    return luaeval("require 'snippy'.can_jump(_A)", direction)
endfunction
