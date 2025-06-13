local main = require('snippy.main')

describe('Core', function()
    setup(function()
        main.add_snippets({
            lua = {
                ['hello'] = 'Hello, snippy!',
                ['multiline'] = 'Line1\nLine2',
            },
        }, { priority = 1000 })
    end)

    it('get snippets', function()
        vim.cmd('set filetype=lua')
        local snippets = main.get_snippets()
        assert.is_not.same({}, snippets)
        assert.is_same('Hello, snippy!', snippets.lua.hello.body)
        assert.is_same('multiline', snippets.lua.multiline.trigger)
    end)

    it('get snippets by scope', function()
        vim.cmd('set filetype=lua')
        local snippets = main.get_snippets('lua')
        assert.is_same(2, vim.tbl_count(snippets))
        assert.is_same(1000, snippets.hello.priority)
    end)
end)
