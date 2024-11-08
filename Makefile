FILTER ?= .*

NEOVIM_TEST_VERSION := v0.10.2
NEOVIM_RUNNER_VERSION ?= v0.10.2

nvim-test:
	git clone --depth 1 https://github.com/lewis6991/nvim-test
	nvim-test/bin/nvim-test --init

vim-snippets:
	git clone --depth 1 https://github.com/honza/vim-snippets

export TEST_COLORS ?= 1

export BUSTED_ARGS = -v --lazy --shuffle \
	--filter=$(FILTER) \
	--lpath=$(PWD)/test/functional/?.lua

functionaltest: nvim-test
	nvim-test/bin/nvim-test test/functional \
		--lpath=$(PWD)/lua/?.lua \
		--lpath=$(PWD)/test/functional/?.lua \
		--verbose \
		--coverage

	-@stty sane

unittest: vim-snippets
	vusted --shuffle test/unit

test: functionaltest unittest

stylua-check:
	stylua -c lua/ test/

stylua-format:
	stylua lua/ test/
