# Snippy

A Lua-based snippets plugin for Neovim **0.5.0+**.

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

## Advantages

These are some of the advantages of this plugin when compared with other snippet plugins for Vim/Neovim:

* No dependence on any external plugin or library.
* Only core Neovim. No need to install Python or any other external language.
* Because it uses the built-in `extmarks` feature, there is no insertion of markers in the text.
* No need to edit JSON files by hand. Snippets file format is much simpler and speeds up creating snippets.
* No need to defined snippets in Lua or Vimscript code.
* Simple and standard snippet syntax.

## Known bugs

* There is a bug in Neovim where `extmarks` are extended to the beginning of the completed item when the `complete()` function is called and a completion menu is shown, even if the user does not select or confirm anything. See the [bug report][1] for more information.

[1]: https://github.com/neovim/neovim/issues/13816

## License

MIT license.
