FILTER=.*

INIT_LUAROCKS := eval $$(luarocks --lua-version=5.1 path) &&

# .DEFAULT_GOAL := build

NEOVIM_BRANCH ?= master

ifeq ($(NEOVIM_BRANCH),master)
	RUNNER = neovim/build/bin/nvim -ll $(PWD)/neovim/test/busted_runner.lua
else
	RUNNER = $(PWD)/neovim/.deps/usr/bin/busted
endif

neovim:
	git clone --depth 1 https://github.com/neovim/neovim --branch $(NEOVIM_BRANCH)
	make -C $@

vim-snippets:
	git clone --depth 1 https://github.com/honza/vim-snippets

export TEST_COLORS=1

functionaltest: neovim vim-snippets
	$(INIT_LUAROCKS) VIMRUNTIME=$(PWD)/neovim/runtime \
		$(RUNNER) \
		-v \
		--shuffle \
		--lazy \
		--helper=$(PWD)/test/functional/preload.lua \
		--output test.busted.outputHandlers.nvim \
		--lpath=$(PWD)/neovim/?.lua \
		--lpath=$(PWD)/neovim/build/?.lua \
		--lpath=$(PWD)/neovim/runtime/lua/?.lua \
		--lpath=$(PWD)/?.lua \
		--lpath=$(PWD)/lua/?.lua \
		--filter=$(FILTER) \
		$(PWD)/test/functional

	-@stty sane

unittest:
	VIMRUNTIME=$(PWD)/neovim/runtime/ \
		VUSTED_NVIM=$(PWD)/neovim/build/bin/nvim \
		vusted --shuffle test/unit

test: functionaltest unittest

stylua-check:
	stylua -c lua/ test/

stylua-format:
	stylua lua/ test/
