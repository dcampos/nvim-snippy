" Syntax highlighting for .snippet files (used for snipMate.vim)
" Hopefully this should make snippets a bit nicer to write!
syn match placeHolder '\${\d\+\(:.\{-}\)\=}' contains=snipCommand
syn match tabStop '\$\d\+'
syn match snipEscape '\\\\\|\\`'
syn match snipCommand '\%(\\\@<!\%(\\\\\)*\)\@<=`.\{-}\%(\\\@<!\%(\\\\\)*\)\@<=`'

syn region choice start='\${\d\+|' end='|}' contains=choiceValue
syn match choiceValue '[|,]\zs[^,|]\+\ze[|,]' contained

syn match transform '\${\d\+/.\{-}/.\{-}/\=}'

hi link placeHolder   Special
hi link tabStop       Special
hi link snipEscape    SpecialChar
hi link snipCommand   String
hi link choice        Special
hi link choiceValue   Keyword
hi link transform     Special
