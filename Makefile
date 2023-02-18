FILTER ?= .*

NEOVIM_BRANCH ?= master

neovim:
	git clone --depth 1 https://github.com/neovim/neovim --branch $(NEOVIM_BRANCH)
	make -C $@

vim-snippets:
	git clone --depth 1 https://github.com/honza/vim-snippets

export TEST_COLORS ?= 1

export BUSTED_ARGS = -v --lazy --shuffle \
	--filter=$(FILTER) \
	--lpath=$(PWD)/test/functional/?.lua

functionaltest: neovim vim-snippets
	SNIPPY_PATH=$(PWD) TEST_FILE=$(PWD)/test/functional \
		make -C neovim functionaltest

	-@stty sane

unittest:
	vusted --shuffle test/unit

test: functionaltest unittest

stylua-check:
	stylua -c lua/ test/

stylua-format:
	stylua lua/ test/
