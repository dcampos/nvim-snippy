local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eval = helpers.clear, helpers.command, helpers.eval
local feed, alter_slashes, meths = helpers.feed, helpers.alter_slashes, helpers.meths
local insert = helpers.insert
local eq, neq, ok = helpers.eq, helpers.neq, helpers.ok
local sleep = helpers.sleep

describe("Snippy tests", function ()
    local screen

    before_each(function()
        clear()
        screen = Screen.new(81, 15)
        screen:attach()

        command('set rtp+=' .. alter_slashes('../snippy/'))
        command('source ' .. alter_slashes('../snippy/plugin/snippy.vim'))
        command('lua snippy = require("snippy")')
    end)

    after_each(function ()
        screen:detach()
    end)

    it("Read scopes", function ()
        command("set filetype=lua")
        eq({_ = {}, lua = {}}, meths.execute_lua([[return snippy.snippets]], {}))
    end)

    it("Read snippets", function ()
        command("lua snippy.setup({snippet_dirs = '../snippy/test/'})")
        command("set filetype=")
        local snips = {
            test1 = {kind = 'snipmate', prefix = 'test1', body = {'This is the first test.'}},
            test2 = {kind = 'snipmate', prefix = 'test2', body = {'This is the second test.'}},
        }
        neq(nil, meths.execute_lua([[return require 'snippy.shared'.config.snippet_dirs]], {}))
        neq({}, meths.execute_lua([[return require 'snippy.reader.snipmate'.list_available_scopes()]], {}))
        eq({_ = snips}, meths.execute_lua([[return snippy.snippets]], {}))
    end)

    it("Read vim-snippets snippets", function ()
        local snippet_dirs = '../vim-snippets/'
        command(string.format([[
            lua snippy.setup({
                snippet_dirs = '%s',
                get_scopes = function () return {vim.bo.ft} end,
            })
        ]], snippet_dirs))
        local scopes = eval([[luaeval('require "snippy.reader.snipmate".list_available_scopes()')]])
        neq({}, scopes)
        local total_failed = {}
        for _, scope in ipairs(scopes) do
            command("set filetype=" ..  scope)
            local snips = meths.execute_lua([[return snippy.snippets]], {})
            neq(nil, snips[scope])
            local failed = meths.execute_lua([[
                local scope = vim.bo.ft
                local failed = {}
                for _, snip in pairs(snippy.snippets[scope]) do
                    local text = table.concat(snip.body, '\n')
                    local ok, parsed, pos = require 'snippy.parser'.parse_snipmate(text, 1)
                    if pos ~= #text + 1 then
                        table.insert(failed, {snip, pos, #text+1})
                    end
                end
                return failed
            ]], {})
            if #failed > 0 then
                total_failed[scope] = failed
                break
            end
        end
        eq({}, total_failed)
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
        eq(true, meths.execute_lua([[return snippy.is_active()]], {}))
    end)

    it("Jump back", function ()
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

    it("Apply transform", function ()
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

    it("Apply transform with escaping", function ()
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

    it("Clear state on move", function ()
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

    it("Jump from select to insert", function ()
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

    it("Jump and mirror correctly", function ()
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

    it("Jump correctly when unicode chars present", function ()
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

end)
