# Snippy

A Lua-based snippets plugin for Neovim **0.5**.

## Features

* Uses built-in `extmarks` feature
* Support for defining multiple snippets in a single file
* Support for LSP-style syntax
* Full support for the syntax and file format used by SnipMate
* No dependencies

## Installation

Install using your favorite plugin manager.

Using vim-plug:

```vim
Plug 'dcampos/snippy'
```

There are no snippets installed by default. You can create your own, or install `vim-snippets`:

```vim
Plug 'honza/vim-snippets'
```

## Usage

Snippy comes with no mappings activated by default. So you'll have to define
some, probably.

For example, to use `<Tab>` to expand and jump forward, `<S-Tab` to jump back:

```vim
imap <expr> <Tab> v:lua.snippy.can_expand_or_advance() ? '<Plug>(snippy-expand-or-advance)' : '<Tab>'
imap <expr> <S-Tab> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<S-Tab>'
smap <expr> <Tab> v:lua.snippy.can_jump(1) ? '<Plug>(snippy-next-stop)' : '<Tab>'
smap <expr> <S-Tab> v:lua.snippy.can_jump(-1) ? '<Plug>(snippy-previous-stop)' : '<S-Tab>'
```

You can also define separate mappings to expand and jump forward. See `:help snippy-usage`.

## Adding snippets

By default every `snippets` directory in `runtimepath` will be searched for
snippets. Files with the `.snippet` extension contain a single snippet, while
files with the `.snippets` extension can be used declare multiple snippets
using the following format.

The LSP snippet syntax is almost fully supported, while there is also full
support for SnipMate-style snippets, including Vim evaluated pieces of code
inside backticks (\`\`).

See `:help snippy-usage-snippets` and `:help snippy-snippet-syntax` for more
information.

## Running tests

There are some functional tests available. Clone the Neovim master at the same
level as snippy and run:

```
TEST_FILE=../snippy/test/snippy_spec.lua make functionaltest
```

Parser tests are run separately. Enter snippy/lua and run:

```
busted --exclude-pattern=snippy ../test/
```

You need to have `busted` installed for the above command to succeed.

## Alternatives

There are several snippet plugins for Vim/Neovim.

* [garbas/vim-snipmate][1]: this is a fork of the original SnipMate plugin. Allows defining multiple snippets in a single text file. Depends on some Vimscript libraries, which may be viewed as a con by some people.
* [SirVer/UltiSnips][2]: a Python-based snippet plugin for Vim. Lots of features. Supports SnipMate syntax. Some incompatibilities or performance issues with Neovim have been reported.
* [Shougo/neosnippet.vim][3]: pure Vim plugin. Supports SnipMate syntax and file format. Uses markers inserted in the text.
* [hrsh7th/vim-vsnip][4]: pure Vim plugin that can load snippets from VSCode. Snippets are defined in JSON files, which may not seem convenient sometimes.
* [norcalli/snippets.nvim][5]: Lua-based snippets plugin for Neovim. Snippets must be defined in Lua code.

[1]: https://github.com/garbas/vim-snipmate
[2]: https://github.com/SirVer/UltiSnips
[3]: https://github.com/Shougo/neosnippet.vim
[4]: https://github.com/hrsh7th/vim-vsnip
[5]: https://github.com/norcalli/snippets.nvim

## License

MIT license.
