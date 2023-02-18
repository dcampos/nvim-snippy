local helpers = dofile('test/functional/helpers.lua')

local child = helpers.new_child_neovim()

local eq, neq = helpers.eq, helpers.neq

local feed, lua, lua_get, cmd = child.type_keys, child.lua, child.lua_get, child.cmd

local insert = function(text)
    child.type_keys('i' .. text .. '<Esc>')
end

local function before_each()
    child.restart({ '-u', 'test/functional/minimal_init.lua' })
    lua('_G.snippy = require("snippy")')
    child.lua([[
    require('snippy').setup({
        snippet_dirs = 'test/snippets',
        enable_auto = true,
        expand_options = {
            c = function()
                return vim.startswith(vim.api.nvim_get_current_line(), '#')
            end,
        },
        choice_delay = 0,
    })]])
    child.cmd('language en_US.utf8')
    child.set_size(10, 50)
end

local T = MiniTest.new_set({
    hooks = { pre_case = before_each, post_once = child.stop },
})

T['detect current scope'] = function()
    lua([[require('snippy').setup({ snippet_dirs = {} })]])
    cmd([[set filetype=lua]])
    eq({ _ = {}, lua = {} }, lua([[return require('snippy').snippets]]))
end

T['insert a basic snippet'] = function()
    cmd('set filetype=')
    feed('itest1')
    child.expect_screenshot()
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    eq('i', child.fn.mode())
end

T['expand a snippet and jump'] = function()
    cmd('set filetype=lua')
    feed('ifor')
    eq(true, lua_get([[require('snippy').can_expand()]]))
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    eq(true, lua_get([[require('snippy').can_jump(1)]]))
    feed('<plug>(snippy-next)')
    child.expect_screenshot()
    eq(true, lua_get([[require('snippy').can_jump(1)]]))
    feed('<plug>(snippy-next)')
    neq(true, lua_get([[require('snippy').is_active()]]))
end

T['expand and select placeholder'] = function()
    cmd('set filetype=lua')
    insert('loc')
    feed('a')
    eq(true, lua_get([[require('snippy').can_expand()]]))
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    eq(true, lua_get([[require('snippy').can_jump(1)]]))
    eq(true, lua_get([[require('snippy').is_active()]]))
    feed('<plug>(snippy-next)')
    child.expect_screenshot()
    neq(true, lua_get([[require('snippy').is_active()]]))
end

T['expand anonymous snippet'] = function()
    cmd('set filetype=')
    feed('i')
    lua('require("snippy").expand_snippet([[local $1 = $0]])')
    child.expect_screenshot()
    eq(true, lua_get([[require('snippy').is_active()]]))
end

T['expand with option'] = function()
    cmd('set filetype=java')
    feed('iacls')
    neq(true, lua_get([[require('snippy').can_expand()]]))
    feed('<c-u>cls')
    eq(true, lua_get([[require('snippy').can_expand()]]))
    feed('<plug>(snippy-expand)')
    eq(true, lua_get([[require('snippy').is_active()]]))
end

T['expand automatically'] = function()
    cmd('set filetype=java')
    feed('ipsvm')
    eq(true, lua_get([[require('snippy').is_active()]]))
    child.expect_screenshot()
end

T['jump back'] = function()
    cmd('set filetype=')
    feed('i')
    lua('snippy.expand_snippet([[$1, $2, $0]])')
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')
    child.expect_screenshot()
    eq(true, lua([[return snippy.can_jump(-1)]]))
    feed('<plug>(snippy-previous)')
    child.expect_screenshot()
end

T['apply transform'] = function()
    cmd('set filetype=')
    feed('i')
    lua('snippy.expand_snippet([[local ${1:var} = ${1/snip/snap/g}]])')
    child.expect_screenshot()
    eq(true, lua([[return snippy.is_active()]]))
    feed('snipsnipsnip')
    child.expect_screenshot()
    eq(true, lua([[return snippy.is_active()]]))
end

T['apply transform with escaping'] = function()
    cmd('set filetype=')
    feed('i')
    lua('snippy.expand_snippet([[local ${1:var} = ${1/\\w\\+/\\U\\0/g}]])')
    eq(true, lua([[return snippy.is_active()]]))
    feed('snippy')
    child.expect_screenshot()
    eq(true, lua([[return snippy.is_active()]]))
end

T['clear state on move'] = function()
    cmd('set filetype=')
    feed('i')
    lua('snippy.expand_snippet([[local $1 = $0]])')
    child.expect_screenshot()
    eq(true, lua([[return snippy.is_active()]]))
    feed('<left>')
    child.expect_screenshot()
    neq(true, lua([[return snippy.is_active()]]))
end

T['jump from select to insert mode'] = function()
    local snip = 'for (\\$${1:foo} = 0; \\$$1 < $2; \\$$1++) {\n\t$0\n}'
    feed('i')
    lua('snippy.expand_snippet(...)', { snip })

    child.expect_screenshot()

    eq(true, lua([[return snippy.is_active()]]))
    eq(true, lua([[return snippy.can_jump(1)]]))
    eq('s', child.fn.mode())

    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    eq(true, lua([[return snippy.is_active()]]))
    eq(true, lua([[return snippy.can_jump(1)]]))
    eq('i', child.fn.mode())

    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    neq(true, lua([[return snippy.is_active()]]))
end

T['jump and mirror correctly'] = function()
    local snip = '${1:var} = $0; // set $1'
    feed('i')
    lua('snippy.expand_snippet(...)', { snip })
    feed('$foo')

    child.expect_screenshot()

    eq(true, lua([[return snippy.is_active()]]))
    eq(true, lua([[return snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    neq(true, lua([[return snippy.is_active()]]))
end

T['mirror nested tab stops'] = function()
    local snip = 'local ${1:module} = require("${2:$1}")'
    lua('snippy.expand_snippet([[' .. snip .. ']])')
    feed('util')
    feed('<plug>(snippy-next)')
    child.expect_screenshot()
    feed('snippy.util')
    eq(true, lua([[return snippy.is_active()]]))
    feed('<plug>(snippy-next)')
    child.expect_screenshot()
    neq(true, lua([[return snippy.is_active()]]))
end

T['nested expansion'] = function()
    local s1 = [[local ${1:var} = ${0:value}]]
    local s2 = [[require(${1:modname})]]
    lua('snippy.expand_snippet([[' .. s1 .. ']])')
    feed('snip')
    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    feed('x<BS>')
    lua('snippy.expand_snippet([[' .. s2 .. ']])')

    child.expect_screenshot()

    eq(true, lua_get([[snippy.is_active()]]))
end

T['jump correctly when unicode chars present'] = function()
    local snip = 'local ${1:var} = $2 -- ▴ $0'
    feed('iç')
    lua('snippy.expand_snippet([[' .. snip .. ']])')

    child.expect_screenshot()

    feed('snippy')
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    eq(true, lua_get([[snippy.is_active()]]))
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    neq(true, lua_get([[snippy.is_active()]]))
end

T['jump in the correct order'] = function()
    local snip = '${1:var1}\n${2:var2} ${3:var3}\n$2 $3 $3 ${4:var4}\n$3 $3 $4'
    lua('snippy.expand_snippet([[' .. snip .. ']])')
    eq(true, lua_get([[snippy.is_active()]]))
    eq(1, lua_get([[require 'snippy.buf'.current_stop]]))
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')
    eq(2, lua_get([[require 'snippy.buf'.current_stop]]))
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')
    eq(true, lua_get([[snippy.can_jump(1)]]))
    feed('<plug>(snippy-next)')

    child.expect_screenshot()

    eq(9, lua_get([[require 'snippy.buf'.current_stop]]))
end

-- See: https://github.com/dcampos/nvim-snippy/issues/66
T['transform and jumps correctly'] = function()
    local snip = [[scanf("%d${1/[^,]*,[^,]*/%d/g}", ${1:&n});]]
    lua('snippy.expand_snippet([[' .. snip .. ']])')
    feed('&a, $b, $c')
    child.expect_screenshot()
    eq(true, lua_get([[snippy.is_active()]]))
end

T['cut text and expand it in normal mode'] = function()
    feed('iinner line<Esc>0')
    feed('<plug>(snippy-cut-text)$')
    lua('snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])')
    child.expect_screenshot()
    eq(true, lua_get([[snippy.is_active()]]))
end

T['cut text and expand it in visual mode'] = function()
    feed('iinner line<Esc>')
    feed('V<plug>(snippy-cut-text)')
    lua('snippy.expand_snippet([[first line\n${0:$VISUAL}\nsecond line]])')
    child.expect_screenshot()
    eq(true, lua_get([[snippy.is_active()]]))
end

T['present a choice menu and select an option'] = function()
    lua('snippy.expand_snippet([[${1|snip,snap,foo,bar|} = $0]])')
    vim.loop.sleep(100)
    feed('<Down><C-y>')
    child.expect_screenshot()
    eq(true, lua_get([[snippy.is_active()]]))
    lua([[snippy.next()]])
    neq(true, lua_get([[snippy.is_active()]]))
end

T['hide choice menu when jumping'] = function()
    lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|}\n$0]])')
    eq(1, child.fn.pumvisible())
    lua('snippy.next()')
    eq(0, child.fn.pumvisible())
    neq(true, lua_get([[snippy.is_active()]]))
    lua('snippy.expand_snippet([[${1|choice1,choice2,choice3|} $0]])')
    eq(1, child.fn.pumvisible())
    lua('snippy.next()')
    eq(0, child.fn.pumvisible())
    neq(true, lua_get([[snippy.is_active()]]))
end

T['remove children from changed placeholder'] = function()
    lua('snippy.expand_snippet([[class MyClass ${1:extends ${2:Super} } {\n\t$0\n}]])')
    child.expect_screenshot()
    lua([[snippy.next()]])
    child.expect_screenshot()
    lua([[snippy.previous()]])
    -- Change parent placeholder
    feed('<BS>')
    lua([[snippy.next()]])
    child.expect_screenshot()
    neq(true, lua_get([[snippy.is_active()]]))
end

T['undo changes to mirrored stops'] = function()
    lua('snippy.expand_snippet([[local ${1:var} = $1]])')
    feed('undo_this')
    child.expect_screenshot()
    feed('<Esc>u<C-l>')
    child.expect_screenshot()
    eq(true, lua_get([[snippy.is_active()]]))
end

T['mirror parent stops'] = function()
    lua('snippy.expand_snippet([[local ${1:${2:${3:snip}}} = $1]])')
    child.expect_screenshot()

    lua([[snippy.next()]])
    lua([[snippy.next()]])
    feed('snap')
    child.expect_screenshot()

    eq(true, lua_get([[snippy.is_active()]]))
end

T['mirror parent of expanded snippet'] = function()
    lua('snippy.expand_snippet([[local $1 = $1]])')
    child.expect_screenshot()

    lua('snippy.expand_snippet([[a_$1_c]])')
    child.expect_screenshot()

    feed('b')
    child.expect_screenshot()

    eq(true, lua_get([[snippy.is_active()]]))
end

T['clear state if current line is deleted'] = function()
    lua('snippy.expand_snippet([[${1:snip}\n${2:snap}]])')
    lua([[snippy.next()]])
    child.expect_screenshot()
    eq(true, lua([[return snippy.is_active()]]))
    feed('<Esc>')
    child.expect_screenshot()
    feed('dd')
    neq(true, lua([[return snippy.is_active()]]))
end

T['expand with beginning option'] = function()
    cmd('set filetype=python')
    insert('begin')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    feed('<Esc>:%d<CR>')
    insert('foo begin')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
end

T['expand with custom option'] = function()
    cmd('set filetype=python')
    insert('comment')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    feed('<Esc>:%d<CR>')
    insert('# comment')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
end

T['expand inside word'] = function()
    cmd('set filetype=python')
    insert('fooinword')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
end

T['expand with word option'] = function()
    cmd('set filetype=python')
    insert('@@@word')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    -- Don't expand this
    feed('<Esc>:%d<CR>')
    insert('fooword')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
end

T['expand with default options'] = function()
    cmd('set filetype=python')
    insert('foo default')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
    -- Don't expand this
    feed('<Esc>:%d<CR>')
    insert('@@@default')
    feed('a')
    feed('<plug>(snippy-expand)')
    child.expect_screenshot()
end

T['mappings'] = function()
    cmd('set filetype=lua')
    lua([[snippy.setup({
        mappings = {
            i = { ['jj'] = 'expand_or_advance' },
            s = { ['kk'] = 'next' }
        }
    })]])
    feed('ilocjj')
    child.expect_screenshot()
    feed('kk')
    child.expect_screenshot()
    neq(true, lua([[return snippy.is_active()]]))
end

T['autocmds'] = function()
    lua([[
        Snippy_autocmds = ''
        vim.api.nvim_create_autocmd('User', {
            pattern = 'Snippy{Expanded,Jumped,Finished}',
            callback = function(args)
                Snippy_autocmds = Snippy_autocmds .. args.match:sub(7)
            end,
        })
    ]])
    local s1 = [[require(${0:modname})]]
    lua('snippy.expand_snippet([[' .. s1 .. ']])')
    lua('snippy.next()')
    eq('ExpandedJumpedFinished', lua([[return Snippy_autocmds]]))
end

return T
