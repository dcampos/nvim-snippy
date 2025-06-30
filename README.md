# Snippy

A minimalist snippets plugin for Neovim **0.7.0+** written in Lua.

## Features

* Uses the built-in `extmarks` feature
* Supports defining multiple snippets in a single file
* Supports for expanding LSP-provided snippets
* Full support for the syntax and file format used by SnipMate
* No dependencies

## Installation

Install using your favorite plugin manager.

For example, using vim-plug:

```vim
Plug 'dcampos/nvim-snippy'
```

There are no snippets installed by default. You can create your own, or install
`vim-snippets`:

```vim
Plug 'honza/vim-snippets'
```

If you want to use Snippy with [nvim-cmp][2], please install and configure
[cmp-snippy][6].

## Usage

Snippy comes with no mappings activated by default, so you need to define
some.

For example, to use `<Tab>` to expand and jump forward, `<S-Tab>` to jump back:

```vim
imap <expr> <Tab> snippy#can_expand_or_advance() ? '<Plug>(snippy-expand-or-advance)' : '<Tab>'
imap <expr> <S-Tab> snippy#can_jump(-1) ? '<Plug>(snippy-previous)' : '<S-Tab>'
smap <expr> <Tab> snippy#can_jump(1) ? '<Plug>(snippy-next)' : '<Tab>'
smap <expr> <S-Tab> snippy#can_jump(-1) ? '<Plug>(snippy-previous)' : '<S-Tab>'
xmap <Tab> <Plug>(snippy-cut-text)
```

When using Lua, you can wrap the above block in a `vim.cmd([[...]])` call, or
use standard `:h vim.keymap.set()` with Lua functions:

```lua
local map = vim.keymap.set

map({ 'i', 's' }, '<Tab>', function()
    return require('snippy').can_expand_or_advance() and '<Plug>(snippy-expand-or-advance)' or '<Tab>'
end, { expr = true })
map({ 'i', 's' }, '<S-Tab>', function()
    return require('snippy').can_jump(-1) and '<Plug>(snippy-previous)' or '<S-Tab>'
end, { expr = true })
map('x', '<Tab>', '<Plug>(snippy-cut-text)')
```

You can also define separate mappings to expand and jump forward. See `:help snippy-usage`
and also the [mapping examples](../../wiki/Mappings) on the Wiki.

## Configuration

Snippy provides an optional `setup()` function for customization. See `:help
snippy-usage-setup` for the available options.

```lua
require('snippy').setup({
    -- Custom options
})
```

## Adding snippets

Normally, you should place your custom snippets in
`$XDG_CONFIG_HOME/nvim/snippets`. However, any `snippets` directory in
`runtimepath` will be searched for snippets. Files with the `.snippet`
extension contain a single snippet, while files with the `.snippets`
extension (most common) can be used to declare multiple snippets.

A basic `lua.snippets` file for Lua, demonstrating some of the plugin's
features, would look like this:

```vim-snippet
# Comments are possible
snippet fun
	function ${1:name}(${2:params})
		${0:$VISUAL}
	end
# Tabstop transformations
snippet upcase
	local ${1:var} = '${1/.*/\U\0/g}'
# Selection menu for predefined choices
snippet choices
	print('My favorite language is: ${1|JavaScript,Lua,Rust|}')
# Eval blocks (Vimscript)
snippet date
	Current date is `strftime('%c')`
# Eval blocks (Lua)
snippet date
	Current date is `!lua os.date()`
# Custom tabstop order
snippet repeat
	repeat
		${2:what}
	while ${1:condition}
```

You can find extensive example snippets in the [honza/vim-snippets][3]
repository, which, if installed, Snippy will also automatically recognize as a
source of snippets.

See `:help snippy-usage-snippets` and `:help snippy-snippet-syntax` for the
details.

## Expanding LSP snippets

The LSP snippet syntax is almost fully supported. If you use a completion plugin
like nvim-cmp, please install the respective integration plugin listed
above in the [Installation](#installation) section.

You can also expand LSP snippets present in completion items provided by Neovim's
built-in `vim.lsp.omnifunc`. See `:help snippy.complete_done()` for details.

## Running tests

There are some functional and unit tests available. To run them, use either:

```
make functionaltest
```

Or:

```
make unittest
```

You need to have [`vusted`][4] installed for running the unit tests.

## Advantages

These are some of the advantages of this plugin when compared with other snippet plugins for Vim/Neovim:

* Core Neovim only, no external dependencies.
* Built-in `extmarks` integration, avoiding insertion of markers in the text.
* Straighforward snippet file format: no need to edit JSON files by hand.
* Eliminates the need to define snippets in Lua or Vimscript code.
* Clean and standard snippet syntax.

## FAQ

#### Is feature X from Ultisnips available?

This question is sometimes asked, and the answer is usually no. UltiSnips is a
great snippet manager for those who want advanced snippet features, such as
Python code evaluation. However, this comes with the cost of being heavy and
complex, whereas Snippy aims to be minimal and simple. That said, UltiSnips
does have some useful features—like auto-trigger—that have been or may be added
in the future to Snippy to improve usability.

#### How can I make Select mode work as in other editors?

In Select mode, some keys may behave differently than in other editors (see
`:help Select-mode`). Check our Wiki section for tips to improve the
experience: [Select mode mappings](../../wiki/Mappings#select-mode-mappings).

**See also:** issues with label [![label: question][~question]](https://github.com/dcampos/nvim-snippy/issues?q=label%3Aquestion).

## Known bugs

* There is a bug in Neovim where `extmarks` are extended to the beginning of
  the completed item when the `complete()` function is called and a completion
  menu is shown, even if the user does not select or confirm anything. See the
  [bug report][1] for more information.

## Acknowledgements

* The legacy snippet parsing code is based on [vsnip][5]'s.
* This plugin would not be possible without all the foundation provided by [SnipMate][7].

## License

MIT license.

[1]: https://github.com/neovim/neovim/issues/13816
[2]: https://github.com/hrsh7th/nvim-cmp
[3]: https://github.com/honza/vim-snippets
[4]: https://github.com/notomo/vusted
[5]: https://github.com/hrsh7th/vim-vsnip
[6]: https://github.com/dcampos/cmp-snippy
[7]: https://github.com/garbas/vim-snipmate
[~question]: https://img.shields.io/github/labels/dcampos/nvim-snippy/question
