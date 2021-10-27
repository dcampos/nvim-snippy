local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eval = helpers.clear, helpers.command, helpers.eval
local feed, alter_slashes, meths = helpers.feed, helpers.alter_slashes, helpers.meths
local insert = helpers.insert
local eq, neq, ok = helpers.eq, helpers.neq, helpers.ok
local sleep, exec_lua = helpers.sleep, helpers.exec_lua

describe("Snippy tests", function ()
    local screen
    local snippy_src = os.getenv('SNIPPY_PATH') or '.'

    local function setup_test_snippets()
        command("lua snippy.setup({snippet_dirs = '" .. alter_slashes(snippy_src .. "/test/'})"))
    end

    before_each(function()
        clear()
        screen = Screen.new(81, 15)
        screen:attach()

        command('set rtp=$VIMRUNTIME')
        command('set rtp+=' .. alter_slashes(snippy_src))
        command('runtime plugin/snippy.vim')
        command('lua snippy = require("snippy")')
        exec_lua([[
            local oldfn = require('snippy.buf').setup_autocmds
            require('snippy.buf').setup_autocmds = function()
                vim.defer_fn(function ()
                    oldfn()
                end, 10)
            end
        ]])
    end)

    after_each(function ()
        screen:detach()
    end)

    it("can detect current scope", function ()
        command("set filetype=lua")
        -- eq({}, eval('&runtimepath'))
        eq({_ = {}, lua = {}}, meths.execute_lua([[return snippy.snippets]], {}))
    end)

    it("can insert a basic snippet", function ()
        setup_test_snippets()
        command("set filetype=")
        insert("test1")
        feed("a")
        feed("<plug>(snippy-expand)")
        -- screen:snapshot_util()
        screen:expect{grid=[[
        This is the first test.^                                                          |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue1, bold = true};
            [2] = {bold = true};
        }}
    end)

    it("can expand a snippet and jump", function ()
        setup_test_snippets()
        command("set filetype=lua")
        insert("for")
        feed("a")
        eq(true, meths.execute_lua([[return snippy.can_expand()]], {}))
        feed("<plug>(snippy-expand)")
        screen:expect{grid=[[
        for ^ in  then                                                                    |
                                                                                         |
        end                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue1, bold = true};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        screen:expect{grid=[[
        for  in ^ then                                                                    |
                                                                                         |
        end                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue1, bold = true};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        neq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("can expand and select placeholder", function ()
        setup_test_snippets()
        command("set filetype=lua")
        insert("loc")
        feed("a")
        eq(true, meths.execute_lua([[return snippy.can_expand()]], {}))
        feed("<plug>(snippy-expand)")
        screen:expect{grid=[[
        local ^v{1:ar} =                                                                      |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {foreground = Screen.colors.Blue, bold = true};
            [3] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        feed("<plug>(snippy-next)")
        screen:expect{grid=[[
        local var = ^                                                                     |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue, bold = true};
            [2] = {bold = true};
        }}
        neq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("can expand anonymous snippet", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[local $1 = $0]])")
        screen:expect{grid=[[
        local ^ =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("can jump back", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[$1, $2, $0]])")
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        screen:expect{grid=[[
        , ^,                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue, bold = true};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.can_jump(-1)]], {}))
        feed("<plug>(snippy-previous)")
        screen:expect{grid=[[
        ^, ,                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue, bold = true};
            [2] = {bold = true};
        }}
    end)

    it("applies transform", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[local ${1:var} = ${1/snip/snap/g}]])")
        screen:expect{grid=[[
        local ^v{1:ar} = var                                                                  |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {bold = true, foreground = Screen.colors.Blue};
            [3] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        feed('snipsnipsnip')
        screen:expect{grid=[[
        local snipsnipsnip^ = snapsnapsnap                                                |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}
        -- neq({current_stop = 0, stops = {}},
        --     meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("applies transform with escaping", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[local ${1:var} = ${1/\\w\\+/\\U\\0/g}]])")
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        -- screen:snapshot_util()
        feed('snippy')
        screen:expect{grid=[[
        local snippy^ = SNIPPY                                                            |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("clears state on move", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[local $1 = $0]])")
        screen:expect{grid=[[
        local ^ =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        feed('<left>')
        screen:expect{grid=[[
        local^  =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}
        sleep(400)
        neq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("can jump from select to insert mode", function ()
        -- command [[lua snippy.setup({ hl_group = 'Search' })]]
        local snip = 'for (\\$${1:foo} = 0; \\$$1 < $2; \\$$1++) {\n\t$0\n}'
        feed("i")
        command("lua snippy.expand_snippet([[" .. snip .. "]])")
        -- feed("bar")

        screen:expect{grid=[[
        for ($^f{1:oo} = 0; $foo < ; $foo++) {                                                |
                                                                                         |
        }                                                                                |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {bold = true, foreground = Screen.colors.Blue1};
            [3] = {bold = true};
        }}

        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        ok(meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")

        -- screen:snapshot_util()
        screen:expect{grid=[[
        for ($foo = 0; $foo < ^; $foo++) {                                                |
                                                                                         |
        }                                                                                |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}

        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        ok(meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")

        -- screen:snapshot_util()
        screen:expect{grid=[[
        for ($foo = 0; $foo < ; $foo++) {                                                |
                ^                                                                         |
        }                                                                                |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}

        eq(false, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("jumps and mirrors correctly", function ()
        -- command [[lua snippy.setup({ hl_group = 'Search' })]]
        local snip = '${1:var} = $0; // set $1'
        feed("i")
        command("lua snippy.expand_snippet([[" .. snip .. "]])")
        feed("$foo")

        -- screen:snapshot_util()
        screen:expect{grid=[[
        $foo^ = ; // set $foo                                                             |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}

        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        ok(meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")

        -- screen:snapshot_util()
        screen:expect{grid=[[
        $foo = ^; // set $foo                                                             |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {bold = true, foreground = Screen.colors.Blue};
            [2] = {bold = true};
        }}

        eq(false, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("jumps correctly when unicode chars present", function ()
        local snip = 'local ${1:var} = $2 -- ▴ $0'
        feed("iç")
        command("lua snippy.expand_snippet([[" .. snip .. "]])")
        -- screen:snapshot_util()

        screen:expect{grid=[[
        çlocal ^v{1:ar} =  -- ▴                                                               |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {foreground = Screen.colors.Blue1, bold = true};
            [3] = {bold = true};
        }}

        feed("snippy")
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")

        -- screen:snapshot_util()
        screen:expect{grid=[[
        çlocal snippy = ^ -- ▴                                                            |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue1, bold = true};
            [2] = {bold = true};
        }}

        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        -- screen:snapshot_util()

        screen:expect{grid=[[
        çlocal snippy =  -- ▴ ^                                                           |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]], attr_ids={
            [1] = {foreground = Screen.colors.Blue1, bold = true};
            [2] = {bold = true};
        }}

        eq(false, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("jumps in the correct order", function ()
        local snip = '${1:var1}\n${2:var2} ${3:var3}\n$2 $3 $3 ${4:var4}\n$3 $3 $4'
        command("lua snippy.expand_snippet([[" .. snip .. "]])")
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
        eq(1, meths.execute_lua([[return require 'snippy.buf'.current_stop]], {}))
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        eq(2, meths.execute_lua([[return require 'snippy.buf'.current_stop]], {}))
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next)")

        screen:expect{grid=[[
        var1                                                                             |
        var2 var3                                                                        |
        var2 var3 var3 ^v{1:ar4}                                                              |
        var3 var3 var4                                                                   |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {bold = true, foreground = Screen.colors.Blue};
            [3] = {bold = true};
        }}

        eq(9, meths.execute_lua([[return require 'snippy.buf'.current_stop]], {}))
    end)

    it("can cut text and expand it in normal mode", function ()
        feed("iinner line<Esc>0")
        feed("<plug>(snippy-cut-text)$")
        command("lua snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])")
        screen:expect{grid=[[
        first line                                                                       |
        ^i{1:nner line}                                                                       |
        second line                                                                      |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {bold = true, foreground = Screen.colors.Blue};
            [3] = {bold = true};
        }}
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it("can cut text and expand it in visual mode", function ()
        feed("iinner line<Esc>")
        feed("V<plug>(snippy-cut-text)")
        command("lua snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])")
        screen:expect{grid=[[
        first line                                                                       |
        ^i{1:nner line}                                                                       |
        second line                                                                      |
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {2:~                                                                                }|
        {3:-- SELECT --}                                                                     |
        ]], attr_ids={
            [1] = {background = Screen.colors.LightGrey};
            [2] = {bold = true, foreground = Screen.colors.Blue};
            [3] = {bold = true};
        }}
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)
end)
