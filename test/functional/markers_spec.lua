local helpers = require('helpers')
local command, eval = helpers.command, helpers.eval
local exec_lua = helpers.exec_lua

describe('Virtual markers', function()
    local screen

    before_each(function()
        helpers.before_each()
        screen = helpers.screen
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

    it('with choice', function()
        if eval('has("nvim-0.10")') == 0 then
            pending('feature requires nvim >= 0.10')
            return true
        end
        exec_lua([[snippy.setup({
            virtual_markers = {
                enabled = true,
                default = '%n:>',
                empty = '%n:|',
                choice = '%n:#',
            }
        })]])
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${2|xxx,zzz,yyy|}${0}]])')
        screen:expect({
            grid = [[
          local ^v{3:ar} = 2:#xxx3:|                             |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)
end)
