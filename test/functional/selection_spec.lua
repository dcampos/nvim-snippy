local helpers = require('helpers')
local command = helpers.command
local exec_lua = helpers.exec_lua

describe('Selection', function()
    local screen

    before_each(function()
        helpers.before_each()
        screen = helpers.screen
    end)

    after_each(function()
        screen:detach()
    end)

    it('inclusive', function()
        command('set filetype=lua')
        command('set selection=inclusive')
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${2:val}${0}]])')
        screen:expect({
            grid = [[
          local ^v{3:ar} = val                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          local var = ^v{3:al}                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)

    it('exclusive', function()
        command('set filetype=lua')
        command('set selection=exclusive')
        exec_lua('snippy.expand_snippet([[local ${1:var} = ${2:val}${0}]])')
        screen:expect({
            grid = [[
          local {3:^var} = val                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
        exec_lua([[snippy.next()]])
        screen:expect({
            grid = [[
          local var = {3:^val}                                   |
          {1:~                                                 }|
          {1:~                                                 }|
          {1:~                                                 }|
          {2:-- SELECT --}                                      |
        ]],
        })
    end)
end)
