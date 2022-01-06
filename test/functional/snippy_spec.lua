local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eval = helpers.clear, helpers.command, helpers.eval
local feed, alter_slashes = helpers.feed, helpers.alter_slashes
local insert = helpers.insert
local eq, neq, ok = helpers.eq, helpers.neq, helpers.ok
local sleep, exec_lua = helpers.sleep, helpers.exec_lua

describe('Snippy', function()
    local screen
    local snippy_src = os.getenv('SNIPPY_PATH') or '.'

    local function setup_test_snippets()
        exec_lua(string.format(
            [[
            snippy.setup({
                snippet_dirs = '%s',
            })]],
            alter_slashes(snippy_src .. '/test/snippets/')
        ))
    end

    before_each(function()
        clear()
        screen = Screen.new(81, 5)
        screen:attach()
        screen:set_default_attr_ids({
            [1] = { foreground = Screen.colors.Blue1, bold = true },
            [2] = { bold = true },
            [3] = { background = Screen.colors.LightGrey },
        })

        command('set rtp=$VIMRUNTIME')
        command('set rtp+=' .. alter_slashes(snippy_src))
        command('runtime plugin/snippy.vim')
        command('lua snippy = require("snippy")')
        exec_lua([[snippy.setup({ choice_delay = 0 })]])
    end)

    after_each(function()
        screen:detach()
    end)

    it('can detect current scope', function()
        command('set filetype=lua')
        eq({ _ = {}, lua = {} }, exec_lua([[return snippy.snippets]]))
    end)

    it('can insert a basic snippet', function()
        setup_test_snippets()
        command('set filetype=')
        insert('test1')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
        This is the first test.^                                                          |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
    end)

    it('can expand a snippet and jump', function()
        setup_test_snippets()
        command('set filetype=lua')
        insert('for')
        feed('a')
        eq(true, exec_lua([[return snippy.can_expand()]]))
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
        for ^ in  then                                                                    |
                                                                                         |
        end                                                                              |
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        for  in ^ then                                                                    |
                                                                                         |
        end                                                                              |
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can expand and select placeholder', function()
        setup_test_snippets()
        command('set filetype=lua')
        insert('loc')
        feed('a')
        eq(true, exec_lua([[return snippy.can_expand()]]))
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
        local ^v{3:ar} =                                                                      |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        local var = ^                                                                     |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can expand anonymous snippet', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[local $1 = $0]])')
        screen:expect({
            grid = [[
        local ^ =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can jump back', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[$1, $2, $0]])')
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        , ^,                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(-1)]]))
        feed('<plug>(snippy-previous)')
        screen:expect({
            grid = [[
        ^, ,                                                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
    end)

    it('applies transform', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[local ${1:var} = ${1/snip/snap/g}]])')
        screen:expect({
            grid = [[
        local ^v{3:ar} = var                                                                  |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('snipsnipsnip')
        screen:expect({
            grid = [[
        local snipsnipsnip^ = snapsnapsnap                                                |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('applies transform with escaping', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[local ${1:var} = ${1/\\w\\+/\\U\\0/g}]])')
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('snippy')
        screen:expect({
            grid = [[
        local snippy^ = SNIPPY                                                            |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('clears state on move', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[local $1 = $0]])')
        screen:expect({
            grid = [[
        local ^ =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<left>')
        screen:expect({
            grid = [[
        local^  =                                                                         |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can jump from select to insert mode', function()
        local snip = 'for (\\$${1:foo} = 0; \\$$1 < $2; \\$$1++) {\n\t$0\n}'
        feed('i')
        command('lua snippy.expand_snippet([[' .. snip .. ']])')

        screen:expect({
            grid = [[
        for ($^f{3:oo} = 0; $foo < ; $foo++) {                                                |
                                                                                         |
        }                                                                                |
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        ok(exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        for ($foo = 0; $foo < ^; $foo++) {                                                |
                                                                                         |
        }                                                                                |
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        ok(exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        for ($foo = 0; $foo < ; $foo++) {                                                |
                ^                                                                         |
        }                                                                                |
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('jumps and mirrors correctly', function()
        local snip = '${1:var} = $0; // set $1'
        feed('i')
        command('lua snippy.expand_snippet([[' .. snip .. ']])')
        feed('$foo')

        screen:expect({
            grid = [[
        $foo^ = ; // set $foo                                                             |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        ok(exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        $foo = ^; // set $foo                                                             |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('mirrors nested tab stops', function()
        local snip = 'local ${1:module} = require("${2:$1}")'
        command('lua snippy.expand_snippet([[' .. snip .. ']])')
        feed('util')
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        local util = require("^u{3:til}")                                                     |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })
        feed('snippy.util')
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        local util = require("snippy.util")^                                              |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('jumps correctly when unicode chars present', function()
        local snip = 'local ${1:var} = $2 -- ▴ $0'
        feed('iç')
        command('lua snippy.expand_snippet([[' .. snip .. ']])')

        screen:expect({
            grid = [[
        çlocal ^v{3:ar} =  -- ▴                                                               |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })

        feed('snippy')
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        çlocal snippy = ^ -- ▴                                                            |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        çlocal snippy =  -- ▴ ^                                                           |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })

        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('jumps in the correct order', function()
        local snip = '${1:var1}\n${2:var2} ${3:var3}\n$2 $3 $3 ${4:var4}\n$3 $3 $4'
        command('lua snippy.expand_snippet([[' .. snip .. ']])')
        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(1, exec_lua([[return require 'snippy.buf'.current_stop]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        eq(2, exec_lua([[return require 'snippy.buf'.current_stop]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        var1                                                                             |
        var2 var3                                                                        |
        var2 var3 var3 ^v{3:ar4}                                                              |
        var3 var3 var4                                                                   |
        {2:-- SELECT --}                                                                     |
        ]],
        })

        eq(9, exec_lua([[return require 'snippy.buf'.current_stop]]))
    end)

    it('can cut text and expand it in normal mode', function()
        feed('iinner line<Esc>0')
        feed('<plug>(snippy-cut-text)$')
        command('lua snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])')
        screen:expect({
            grid = [[
        first line                                                                       |
        ^i{3:nner line}                                                                       |
        second line                                                                      |
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can cut text and expand it in visual mode', function()
        feed('iinner line<Esc>')
        feed('V<plug>(snippy-cut-text)')
        command('lua snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])')
        screen:expect({
            grid = [[
        first line                                                                       |
        ^i{3:nner line}                                                                       |
        second line                                                                      |
        {1:~                                                                                }|
        {2:-- SELECT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can present a choice menu and select an option', function()
        command('lua snippy.expand_snippet([[${1|snip,snap,foo,bar|} = $0]])')
        sleep(100)
        feed('<Down><C-y>')
        screen:expect({
            grid = [[
        snap^ =                                                                           |
        {1:~                                                                                }|
        {1:~                                                                                }|
        {1:~                                                                                }|
        {2:-- INSERT --}                                                                     |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        exec_lua([[snippy.next()]])
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('hides choice menu when jumping', function()
        exec_lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|}\n$0]])')
        eq(1, eval('pumvisible()'))
        exec_lua('snippy.next()')
        eq(0, eval('pumvisible()'))
        eq(false, exec_lua([[return snippy.is_active()]]))
        exec_lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|} $0]])')
        eq(1, eval('pumvisible()'))
        exec_lua('snippy.next()')
        eq(0, eval('pumvisible()'))
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)
end)
