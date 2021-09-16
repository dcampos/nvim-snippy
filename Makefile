FILTER=.*

INIT_LUAROCKS := eval $$(luarocks --lua-version=5.1 path) &&

# .DEFAULT_GOAL := build

NEOVIM_BRANCH ?= stable

neovim:
	git clone --depth 1 https://github.com/neovim/neovim --branch $(NEOVIM_BRANCH)
	make -C $@

vim-snippets:
	git clone --depth 1 https://github.com/honza/vim-snippets

export TEST_COLORS=1

functionaltest: neovim vim-snippets
	$(INIT_LUAROCKS) VIMRUNTIME=$(PWD)/neovim/runtime \
		neovim/.deps/usr/bin/busted \
		-v \
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
	vusted test/unit
