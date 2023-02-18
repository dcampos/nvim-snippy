FILTER ?= .*

.deps/vim-snippets:
	git clone --depth 1 https://github.com/honza/vim-snippets .deps/vim-snippets

.deps/mini.test:
	git clone --depth 1 https://github.com/echasnovski/mini.test .deps/mini.test

functionaltest: .deps/mini.test
	nvim --headless --noplugin -u ./test/functional/minimal_init.lua -c 'lua MiniTest.run()'

unittest: .deps/vim-snippets
		vusted --shuffle test/unit

test: functionaltest unittest

stylua-check:
	stylua -c lua/ test/

stylua-format:
	stylua lua/ test/
