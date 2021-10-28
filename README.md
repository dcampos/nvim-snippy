# Snippy

A Lua-based snippets plugin for Neovim **0.5.0+**.

## Status

The plugin is mostly stable and can be used. Please open an issue if you
find any bug. Also, see the [Known bugs](#known-bugs) section.

## Features

* Uses the built-in `extmarks` feature
* Support for defining multiple snippets in a single file
* Support for expanding LSP provided snippets
* Full support for the syntax and file format used by SnipMate
* No dependencies

## Installation

Install using your favorite plugin manager.

Using vim-plug:

```vim
Plug 'dcampos/nvim-snippy'
```

There are no snippets installed by default. You can create your own, or install
`vim-snippets`:

```vim
Plug 'honza/vim-snippets'
```

If you want to use Snippy with [deoplete.nvim][2], [nvim-compe][3] or [nvim-cmp][4], please install the
corresponding integration plugin:

```vim
Plug 'dcampos/deoplete-snippy'

" Or:
Plug 'dcampos/compe-snippy'

" Or:
Plug 'dcampos/cmp-snippy'
```

## Usage

Snippy comes with no mappings activated by default. So you'll have to define
some, probably.

For example, to use `<Tab>` to expand and jump forward, `<S-Tab` to jump back:

```vim
imap <expr> <Tab> snippy#can_expand_or_advance() ? '<Plug>(snippy-expand-or-next)' : '<Tab>'
imap <expr> <S-Tab> snippy#can_jump(-1) ? '<Plug>(snippy-previous)' : '<Tab>'
smap <expr> <Tab> snippy#can_jump(1) ? '<Plug>(snippy-next)' : '<Tab>'
smap <expr> <S-Tab> snippy#can_jump(-1) ? '<Plug>(snippy-previous)' : '<Tab>'
xmap <Tab> <Plug>(snippy-cut-text)
```

Using the Lua API:

```lua
local snippy = require("snippy")
snippy.setup({
    mappings = {
        is = {
            ["<Tab>"] = "expand_or_advance",
            ["<S-Tab>"] = "previous",
        },
        nx = {
            ["<leader>x"] = "cut_text",
        },
    },
})
```

You can also define separate mappings to expand and jump forward. See `:help snippy-usage`.

## Adding snippets

By default every `snippets` directory in `runtimepath` will be searched for
snippets. Files with the `.snippet` extension contain a single snippet, while
files with the `.snippets` extension can be used to declare multiple snippets.

A basic `lua.snippets` file for Lua showing off some of the plugin's features
would look like this:

```vim-snippet
# Comments are possible
snippet fun
	function ${1:name}(${2:params})
		${0:$VISUAL}
	end
snippet upcase
	local ${1:var} = '${1/.*/\U\0/g}'
snippet choices
	print('My favorite language is: ${1|JavaScript,Lua,Rust|}')
snippet date
	Current date is `strftime('%c')`
# Custom tabstop order
snippet repeat
	repeat
		${2:what}
	while ${1:condition}
```

You can see example snippets by looking at the [honza/vim-snippets][5]
repository, which, if installed, Snippy will also use automatically as a source
of snippets .

See `:help snippy-usage-snippets` and `:help snippy-snippet-syntax` for more
information.

## Expanding LSP snippets

The LSP snippet syntax is almost fully supported. If you use a completion plugin
like Deoplete or Compe, please install the respective integration plugin listed
above in the [Installation](#installation) section.

You can also expand LSP snippets present in completion items provided by Neovim's
bult-in `vim.lsp.omnifunc`. See `:help snippy.complete_done()` for details.

## Running tests

There are some functional and unit tests available. To run them, use either:

```
make functionaltest
```

Or:

```
make unittest
```

You need to have [`vusted`][6] installed for the above command to succeed.

## Advantages

These are some of the advantages of this plugin when compared with other snippet plugins for Vim/Neovim:

* No dependence on any external plugin or library.
* Only core Neovim. No need to install Python or any other external language.
* Because it uses the built-in `extmarks` feature, there is no insertion of markers in the text.
* No need to edit JSON files by hand. Snippets file format is much simpler and may speed up the process of creating snippets.
* No need to defined snippets in Lua or Vimscript code.
* Simple and standard snippet syntax.

## Known bugs

* There is a bug in Neovim where `extmarks` are extended to the beginning of the completed item when the `complete()` function is called and a completion menu is shown, even if the user does not select or confirm anything. See the [bug report][1] for more information.

[1]: https://github.com/neovim/neovim/issues/13816
[2]: https://github.com/Shougo/deoplete.nvim
[3]: https://github.com/hrsh7th/nvim-compe
[4]: https://github.com/hrsh7th/nvim-cmp
[5]: https://github.com/honza/vim-snippets
[6]: https://github.com/notomo/vusted
[7]: https://github.com/hrsh7th/vim-vsnip

## Credits

The snippet parsing code is based on the one that is part of [vsnip][7].

## License

MIT license.
