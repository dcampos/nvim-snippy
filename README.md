# Snippy

A lua-based snippets plugin for Neovim **0.5**.

## Installation

Install using your favorite plugin manager.

Using vim-plug:

```vim
Plug 'dcampos/snippy'
```

## Usage

Snippy comes with no mappings activated by default. So you'll have to define
some, probably.

For example, to use `<Tab>` to expand and jump forward, `<S-Tab` to jump back:

```vim
imap <expr> <Tab> v:lua.snippy.can_expand_or_advance() ? '<Plug>(snippy-expand-or-advance)' : '<Tab>'
imap <expr> <S-Tab> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<Tab>'
smap <expr> <Tab> v:lua.snippy.can_jump(1) ? '<Plug>(snippy-next-stop)' : '<Tab>'
smap <expr> <S-Tab> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<Tab>'
```

Of course, you can also define different mappings to expand and jump forward.
To expand with `<C-]>`, jump forward with `<C-j>`, and jump back with `<C-k>`,
set it up like this:

```vim
imap <expr> <C-]> v:lua.snippy.can_expand() ? '<Plug>(snippy-expand)' : '<C-]>'
imap <expr> <C-j> v:lua.snippy.can_jump(1) ? '<Plug>(snippy-next-stop)' : '<C-j>'
imap <expr> <C-k> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<C-k>'
smap <expr> <C-j> v:lua.snippy.can_jump(1) ? '<Plug>(snippy-next-stop)' : '<C-j>'
smap <expr> <C-k> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<C-k>'
```

You can also define mappings for cutting the currently selected text, to be used later:

```vim
nmap g<Tab> <Plug>(snippy-cut-text)
xmap <Tab> <Plug>(snippy-cut-text)
```

## Running tests

`TODO`

## Comparison

`TODO`

## License

MIT license.
