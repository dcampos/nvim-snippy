local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear, command, eval = helpers.clear, helpers.command, helpers.eval
local alter_slashes = helpers.alter_slashes
local exec_lua = helpers.exec_lua

describe('Virtual markers', function()
    local screen
    local snippy_src = os.getenv('SNIPPY_PATH') or '.'

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

    it('basic', function()
        if eval('has("nvim-0.10")') == 0 then
            pending('feature requires nvim >= 0.10')
            return true
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

    it('with stop numbers', function()
        if eval('has("nvim-0.10")') == 0 then
            pending('feature requires nvim >= 0.10')
            return true
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
