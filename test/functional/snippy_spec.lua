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
                enable_auto = true,
                expand_options = {
                  c = function()
                      return vim.startswith(vim.api.nvim_get_current_line(), '#')
                  end
                }
            })]],
            alter_slashes(snippy_src .. '/test/snippets/')
        ))
    end

    before_each(function()
        clear()
        screen = Screen.new(50, 5)
        screen:attach()
        screen:set_default_attr_ids({
            [1] = { foreground = Screen.colors.Blue1, bold = true },
            [2] = { bold = true },
            [3] = { background = Screen.colors.LightGrey },
        })

        command('set rtp=$VIMRUNTIME')
        command('set rtp+=' .. alter_slashes(snippy_src))
        command('runtime plugin/snippy.lua')
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

    it('can expand with option', function()
        setup_test_snippets()
        command('set filetype=java')
        feed('iacls')
        eq(false, exec_lua([[return snippy.can_expand()]]))
        feed('<c-u>cls')
        eq(true, exec_lua([[return snippy.can_expand()]]))
        feed('<plug>(snippy-expand)')
        eq(true, exec_lua([[return snippy.is_active()]]))
    end)

    it('can expand automatically', function()
        setup_test_snippets()
        command('set filetype=java')
        feed('ipsvm')
        eq(true, exec_lua([[return snippy.is_active()]]))
        screen:expect({
            grid = [[
          public static void main(String[] ^a{3:rgs}) {          |
                                                            |
          }                                                 |
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
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
        command('lua snippy.expand_snippet([[local ${1:var} = ${1/snip/snap/g}]])')
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
        command('lua snippy.expand_snippet([[local ${1:var} = ${1/\\w\\+/\\U\\0/g}]])')
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
        ok(exec_lua([[return snippy.can_jump(1)]]))
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
        ok(exec_lua([[return snippy.can_jump(1)]]))
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
        ok(exec_lua([[return snippy.can_jump(1)]]))
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
        -- screen:snapshot_util()
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

    it('should expand with beginning option', function()
        setup_test_snippets()
        command('set filetype=python')
        insert('begin')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          Expand only if in the beginning of the line!^      |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        feed('<Esc>:%d<CR>')
        insert('foo begin')
        feed('a')
        feed('<plug>(snippy-expand)')
        -- screen:snapshot_util()
        screen:expect({
            grid = [[
          foo begin^                                         |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('should expand with custom option', function()
        setup_test_snippets()
        command('set filetype=python')
        insert('comment')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          comment^                                           |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        feed('<Esc>:%d<CR>')
        insert('# comment')
        feed('a')
        feed('<plug>(snippy-expand)')
        -- screen:snapshot_util()
        screen:expect({
            grid = [[
          # Expand this if on a commented line!^             |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('should expand inside word', function()
        setup_test_snippets()
        command('set filetype=python')
        insert('fooinword')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          fooExpand this inside a word!^                     |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('should expand with word option', function()
        setup_test_snippets()
        command('set filetype=python')
        insert('@@@word')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          @@@Expand this if it is keyword based!^            |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        -- Don't expand this
        feed('<Esc>:%d<CR>')
        insert('fooword')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          fooword^                                           |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
    end)

    it('should expand with default options', function()
        setup_test_snippets()
        command('set filetype=python')
        insert('foo default')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          foo Expand if keyword-delimited word present!^     |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
        -- Don't expand this
        feed('<Esc>:%d<CR>')
        insert('foodefault')
        feed('a')
        feed('<plug>(snippy-expand)')
        screen:expect({
            grid = [[
          foodefault^                                        |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- INSERT --}                                      |
        ]],
        })
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

    it('virtual markers', function()
        if exec_lua([[return vim.fn.has('nvim-0.10')]]) == 0 then
            return
        end
        command('set filetype=lua')
        exec_lua([[snippy.setup({
            virtual_markers ={
                enabled = true,
                default = '>',
                empty = '|',
            }
        })]])
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${2:val}${0}]])')
        screen:expect({
            grid = [[
          local ^v{3:ar} = >val|                                 |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          local >var = ^v{3:al}|                                 |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)

    it('virtual markers with numbers', function()
        if exec_lua([[return vim.fn.has('nvim-0.10')]]) == 0 then
            return
        end
        command('set filetype=lua')
        exec_lua([[snippy.setup({
            virtual_markers = {
                enabled = true,
                default = '%n:>',
                empty = '%n:|',
            }
        })]])
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${2:val}${0}]])')
        screen:expect({
            grid = [[
          local ^v{3:ar} = 2:>val3:|                             |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          local 1:>var = ^v{3:al}3:|                             |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)
end)
