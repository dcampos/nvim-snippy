# Snippy

A Lua-based snippets plugin for Neovim **0.5.0+**.

**This is a WIP plugin currently. There may be bugs (see the [Known bugs](#known-bugs)
section), and breaking changes may occur.**

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

If you want to use Snippy with [Deoplete][2] or [Compe][3], please install the
corresponding integration plugin:

```vim
Plug 'dcampos/deoplete-snippy'
```

Or:

```vim
Plug 'dcampos/compe-snippy'
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
```

You can also define separate mappings to expand and jump forward. See `:help snippy-usage`.

## Adding snippets

By default every `snippets` directory in `runtimepath` will be searched for
snippets. Files with the `.snippet` extension contain a single snippet, while
files with the `.snippets` extension can be used to declare multiple snippets.

A basic `lua.snippets` file for Lua would look like this:

```vim-snippet
snippet fun
	function ${1:name}(${2:params})
		${0:$VISUAL}
	end
snippet while
	while ${1:values} do
		${0:$VISUAL}
	end
snippet loc
	local ${1:var} = ${0:value}
snippet fori
	for ${1:i}, ${2:value} in ipairs(${3:table}) do
		${0:$VISUAL}
	end
snippet forp
	for ${1:key}, ${2:value} in pairs(${3:table}) do
		${0:$VISUAL}
	end
```

You can see example snippets by looking at the [honza/vim-snippets][4]
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

There are some functional tests available. Clone the Neovim master at the same
level as Snippy and run:

```
TEST_FILE=../snippy/test/snippy_spec.lua make functionaltest
```

Parser tests are run separately. Enter the `snippy/lua` directory and run:

```
busted --exclude-pattern=snippy ../test/
```

You need to have `busted` installed for the above command to succeed.

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
[4]: https://github.com/honza/vim-snippets
[5]: https://github.com/hrsh7th/vim-vsnip

## Credits

The snippet parsing code is based on the one that is part of [Vsnip][5].

## License

MIT license.
