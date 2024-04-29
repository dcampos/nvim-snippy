local helpers = require('helpers')
local Screen = require('test.functional.ui.screen')
local clear, command, eval = helpers.clear, helpers.command, helpers.eval
local feed, alter_slashes = helpers.feed, helpers.alter_slashes
local insert = helpers.insert
local eq, neq, ok, skip = helpers.eq, helpers.neq, helpers.ok, helpers.skip
local sleep, exec_lua = helpers.sleep, helpers.exec_lua

describe('Options', function()
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

        local defaults = {
            [1] = { foreground = Screen.colors.Blue1, bold = true },
            [2] = { bold = true },
            [3] = { background = Screen.colors.LightGrey },
        }

        if eval('has("nvim-0.10")') > 0 then
            command('colorscheme vim')
            defaults[3] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }
        end

        screen:set_default_attr_ids(defaults)
        command('set rtp=$VIMRUNTIME')
        command('set rtp+=' .. alter_slashes(snippy_src))
        command('runtime plugin/snippy.lua')
        command('lua snippy = require("snippy")')
        exec_lua([[snippy.setup({ choice_delay = 0 })]])
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
