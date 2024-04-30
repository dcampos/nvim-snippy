local helpers = require('helpers')
local command = helpers.command
local feed = helpers.feed
local insert = helpers.insert
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local setup_test_snippets = helpers.setup_test_snippets

describe('Options', function()
    local screen

    before_each(function()
        helpers.before_each()
        screen = helpers.screen
    end)

    after_each(function()
        screen:detach()
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
end)
