local helpers = require('helpers')
local command, eval = helpers.command, helpers.eval
local feed = helpers.feed
local insert = helpers.insert
local eq, neq = helpers.eq, helpers.neq
local sleep = vim and vim.uv and vim.uv.sleep or helpers.sleep
local exec_lua = helpers.exec_lua
local setup_test_snippets = helpers.setup_test_snippets

describe('Core', function()
    local screen

    before_each(function()
        helpers.before_each()
        screen = helpers.screen
    end)

    after_each(function()
        screen:detach()
    end)

    -- Tip: use screen:snapshot_util() to get current screen state

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
        This is the first test.^                           |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        for ^ in  then                                     |
                                                          |
        end                                               |
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        for  in ^ then                                     |
                                                          |
        end                                               |
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        local ^v{3:ar} =                                       |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        local var = ^                                      |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        local ^ =                                          |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        , ^,                                               |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.can_jump(-1)]]))
        feed('<plug>(snippy-previous)')
        screen:expect({
            grid = [[
        ^, ,                                               |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('applies transform', function()
        command('set filetype=')
        feed('i')
        -- TODO: this should work only for snipmate snippets
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${1/snip/snap/g}]])')
        screen:expect({
            grid = [[
        local ^v{3:ar} = var                                   |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('snipsnipsnip')
        screen:expect({
            grid = [[
        local snipsnipsnip^ = snapsnapsnap                 |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('applies transform with escaping', function()
        command('set filetype=')
        feed('i')
        -- TODO: this should work only for snipmate snippets
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${1/\\w\\+/\\U\\0/g}]])')
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('snippy')
        screen:expect({
            grid = [[
        local snippy^ = SNIPPY                             |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('applies transform to variables', function()
        command('file test.lua')
        feed('i')
        -- TODO: this should work only for snipmate snippets
        exec_lua('snippy.expand_snippet([[${TM_FILENAME_BASE/./\\u&/}]])')
        screen:expect({
            grid = [[
          Test^                                              |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('clears state on move', function()
        command('set filetype=')
        feed('i')
        command('lua snippy.expand_snippet([[local $1 = $0]])')
        screen:expect({
            grid = [[
        local ^ =                                          |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<left>')
        screen:expect({
            grid = [[
        local^  =                                          |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        for ($^f{3:oo} = 0; $foo < ; $foo++) {                 |
                                                          |
        }                                                 |
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        for ($foo = 0; $foo < ^; $foo++) {                 |
                                                          |
        }                                                 |
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        for ($foo = 0; $foo < ; $foo++) {                 |
                ^                                          |
        }                                                 |
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        $foo^ = ; // set $foo                              |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        $foo = ^; // set $foo                              |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        local util = require("^u{3:til}")                      |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
        ]],
        })
        feed('snippy.util')
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
        local util = require("snippy.util")^               |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('mirrors should start with content', function()
        exec_lua('snippy.expand_snippet([[${1:snip} | ${2:snap} | ${2/./\\u\\0/g}]])')
        screen:expect({
            grid = [[
            ^s{3:nip} | snap | SNAP                                |
            {1:~                                                 }|
            {1:~                                                 }|
            {1:~                                                 }|
            {2:-- SELECT --}                                      |
        ]],
        })
    end)

    it('mirrors should override placeholders', function()
        exec_lua('snippy.expand_snippet([[${1:snip} | ${2:snap} | ${2:ignored}]])')
        screen:expect({
            grid = [[
            ^s{3:nip} | snap | snap                                |
            {1:~                                                 }|
            {1:~                                                 }|
            {1:~                                                 }|
            {2:-- SELECT --}                                      |
        ]],
        })
    end)

    it('should mirror tabstop nested in another placeholder', function()
        exec_lua('snippy.expand_snippet([[${1:snip} | ${2/.*/\\U\\0/} | ${3:aaa${2:nested}}]])')
        screen:expect({
            grid = [[
          ^s{3:nip} | NESTED | aaanested                         |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })

        feed('<plug>(snippy-next)')
        feed('zzz')
        screen:expect({
            grid = [[
          snip | ZZZ | aaazzz^                               |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('should skip tranform mirrors that come first', function()
        exec_lua('snippy.expand_snippet([[${1:zzz} ${2/snip/SNAP} = ${2:snip}]])')
        screen:expect({
            grid = [[
            ^z{3:zz} SNAP = snip                                   |
            {1:~                                                 }|
            {1:~                                                 }|
            {1:~                                                 }|
            {2:-- SELECT --}                                      |
        ]],
        })
        feed('<plug>(snippy-next)')
        screen:expect({
            grid = [[
          zzz SNAP = ^s{3:nip}                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)

    it('does nested expansion', function()
        local s1 = [[local ${1:var} = ${0:value}]]
        local s2 = [[require(${1:modname})]]
        exec_lua('snippy.expand_snippet([[' .. s1 .. ']])')
        feed('snip')
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
          local snip = ^v{3:alue}                                |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })

        feed('x<BS>')
        exec_lua('snippy.expand_snippet([[' .. s2 .. ']])')

        screen:expect({
            grid = [[
          local snip = require(^m{3:odname})                     |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('jumps correctly when unicode chars present', function()
        local snip = 'local ${1:var} = $2 -- ▴ $0'
        feed('iç')
        command('lua snippy.expand_snippet([[' .. snip .. ']])')

        screen:expect({
            grid = [[
        çlocal ^v{3:ar} =  -- ▴                                |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
        ]],
        })

        feed('snippy')
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        çlocal snippy = ^ -- ▴                             |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
        eq(true, exec_lua([[return snippy.can_jump(1)]]))
        feed('<plug>(snippy-next)')

        screen:expect({
            grid = [[
        çlocal snippy =  -- ▴ ^                            |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
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
        var1                                              |
        var2 var3                                         |
        var2 var3 var3 ^v{3:ar4}                               |
        var3 var3 var4                                    |
        {2:-- SELECT --}                                      |
        ]],
        })

        eq(9, exec_lua([[return require 'snippy.buf'.current_stop]]))
    end)

    -- See: https://github.com/dcampos/nvim-snippy/issues/66
    it('transforms and jumps correctly', function()
        local snip = [[scanf("%d${1/[^,]*,[^,]*/%d/g}", ${1:&n});]]
        exec_lua('snippy.expand_snippet([[' .. snip .. ']])')
        feed('&a, $b, $c')
        screen:expect({
            grid = [[
        scanf("%d%d%d", &a, $b, $c^);                      |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can cut text and expand it in normal mode', function()
        feed('iinner line<Esc>0')
        feed('<plug>(snippy-cut-text)$')
        command('lua snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])')
        screen:expect({
            grid = [[
        first line                                        |
        ^i{3:nner line}                                        |
        second line                                       |
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
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
        first line                                        |
        ^i{3:nner line}                                        |
        second line                                       |
        {1:~                                                 }|
        {2:-- SELECT --}                                      |
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
        snap^ =                                            |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {2:-- INSERT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        exec_lua([[snippy.next()]])
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('hides choice menu when jumping', function()
        exec_lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|}\n$0]])')
        sleep(20)
        eq(1, eval('pumvisible()'))
        exec_lua('snippy.next()')
        eq(0, eval('pumvisible()'))
        eq(false, exec_lua([[return snippy.is_active()]]))
        exec_lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|} $0]])')
        sleep(20)
        eq(1, eval('pumvisible()'))
        exec_lua('snippy.next()')
        eq(0, eval('pumvisible()'))
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('removes children from changed placeholder', function()
        exec_lua('snippy.expand_snippet([[class MyClass ${1:extends ${2:Super} } {\n\t$0\n}]])')
        screen:expect({
            grid = [[
          class MyClass ^e{3:xtends Super } {                    |
                                                            |
          }                                                 |
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          class MyClass extends ^S{3:uper}  {                    |
                                                            |
          }                                                 |
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.previous()]])
        -- Change parent placeholder
        feed('<BS>')
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          class MyClass  {                                  |
                  ^                                          |
          }                                                 |
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('should undo changes to mirrored stops', function()
        exec_lua('snippy.expand_snippet([[local ${1:var} = $1]])')
        feed('undo_this')
        screen:expect({
            grid = [[
          local undo_this^ = undo_this                       |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        feed('<Esc>u<C-l>')
        screen:expect({
            grid = [[
          local ^var = var                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
                                                            |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('mirror parent stops', function()
        screen:try_resize(50, 3)
        exec_lua('snippy.expand_snippet([[local ${1:${2:${3:snip}}} = $1]])')
        screen:expect({
            grid = [[
            local ^s{3:nip} = snip                                 |
            {1:~                                                 }|
            {2:-- SELECT --}                                      |
        ]],
        })

        exec_lua([[snippy.next()]])
        exec_lua([[snippy.next()]])
        feed('snap')
        screen:expect({
            grid = [[
            local snap^ = snap                                 |
            {1:~                                                 }|
            {2:-- INSERT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('mirror parent of expanded snippet', function()
        screen:try_resize(50, 3)
        exec_lua('snippy.expand_snippet([[local $1 = $1]])')
        screen:expect({
            grid = [[
            local ^ =                                          |
            {1:~                                                 }|
            {2:-- INSERT --}                                      |
        ]],
        })

        exec_lua('snippy.expand_snippet([[a_$1_c]])')
        screen:expect({
            grid = [[
            local a_^_c = a__c                                 |
            {1:~                                                 }|
            {2:-- INSERT --}                                      |
        ]],
        })

        feed('b')
        screen:expect({
            grid = [[
            local a_b^_c = a_b_c                               |
            {1:~                                                 }|
            {2:-- INSERT --}                                      |
        ]],
        })

        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('should clear state if current line is deleted', function()
        exec_lua('snippy.expand_snippet([[${1:snip}\n${2:snap}]])')
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          snip                                              |
          ^s{3:nap}                                              |
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        eq(true, exec_lua([[return snippy.is_active()]]))
        feed('<Esc>')
        screen:expect({
            grid = [[
          snip                                              |
          ^snap                                              |
          {1:~                                                 }|
          {1:~                                                 }|
                                                            |
        ]],
        })
        feed('dd')
        eq(false, exec_lua([[return snippy.is_active()]]))
    end)

    it('mappings', function()
        setup_test_snippets()
        command('set filetype=lua')
        exec_lua([[snippy.setup({
            mappings = {
                i = { ['jj'] = 'expand_or_advance' },
                s = { ['kk'] = 'next' }
            }
        })]])
        feed('ilocjj')
        screen:expect({
            grid = [[
          local ^v{3:ar} =                                       |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        feed('kk')
        screen:expect({
            grid = [[
          local var = ^                                      |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('autocmds', function()
        exec_lua([[
            Snippy_autocmds = ''
            vim.api.nvim_create_autocmd('User', {
                pattern = 'Snippy{Expanded,Jumped,Finished}',
                callback = function(args)
                    Snippy_autocmds = Snippy_autocmds .. args.match:sub(7)
                end,
            })
        ]])
        local s1 = [[require(${0:modname})]]
        exec_lua('snippy.expand_snippet([[' .. s1 .. ']])')
        exec_lua('snippy.next()')
        eq('ExpandedJumpedFinished', exec_lua([[return Snippy_autocmds]]))
    end)

    it('finish', function()
        exec_lua('snippy.expand_snippet([[snip $1 snap]])')
        eq(true, exec_lua([[return snippy.is_active()]]))
        exec_lua('snippy.finish()')
        neq(true, exec_lua([[return snippy.is_active()]]))
    end)
end)
