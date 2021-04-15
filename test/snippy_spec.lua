local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command = helpers.clear, helpers.command
local feed, alter_slashes, meths = helpers.feed, helpers.alter_slashes, helpers.meths
local insert = helpers.insert
local eq, neq = helpers.eq, helpers.neq
local sleep = helpers.sleep

describe("Snippy tests", function ()
    local screen

    before_each(function()
        clear()
        screen = Screen.new(81, 15)
        screen:attach()

        command('set rtp+=' .. alter_slashes('../snippy/'))
        command('source ' .. alter_slashes('../snippy/plugin/snippy.vim'))
    end)

    after_each(function ()
        screen:detach()
    end)

    it("Read scopes", function ()
        command("set filetype=lua")
        eq({_ = {}, lua = {}}, meths.execute_lua([[return snippy.snips]], {}))
    end)

    it("Read snippets", function ()
        command("lua snippy.setup({snippet_dirs = '../snippy/test/'})")
        command("set filetype=")
        local snips = {
            test1 = {prefix = 'test1', body = {'This is the first test.'}},
            test2 = {prefix = 'test2', body = {'This is the second test.'}},
        }
        eq({_ = snips}, meths.execute_lua([[return snippy.snips]], {}))
    end)

    it("Insert basic snippet", function ()
        command("lua snippy.setup({snippet_dirs = '../snippy/test/'})")
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

    it("Insert snippet and jump", function ()
        command("lua snippy.setup({snippet_dirs = '../snippy/test/'})")
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
        feed("<plug>(snippy-next-stop)")
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
        feed("<plug>(snippy-next-stop)")
        eq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
    end)

    it("Expand and select placeholder", function ()
        command("lua snippy.setup({snippet_dirs = '../snippy/test/'})")
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
        neq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
        feed("<plug>(snippy-next-stop)")
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
        eq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
    end)

    it("Expand anonymous snippet", function ()
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
        neq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
    end)

    it("Jump back", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[$1, $2, $0]])")
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
        feed("<plug>(snippy-next-stop)")
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
        feed("<plug>(snippy-previous-stop)")
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

    it("Apply transform", function ()
        command("set filetype=")
        feed("i")
        command("lua snippy.expand_snippet([[local ${1:var} = ${1/foo/bar/g}]])")
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
        neq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
        feed('foofoofoo')
        screen:expect{grid=[[
        local foofoofoo^ = barbarbar                                                      |
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
        neq({current_stop = 0, stops = {}},
            meths.execute_lua([[return require 'snippy.buf'.state()]], {}))
        eq(true, meths.execute_lua([[return snippy.can_jump(1)]], {}))
    end)
end)
