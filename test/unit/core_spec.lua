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

    it('adds snippets without optional options', function()
        main.add_snippets({ api = { hello = 'Hello, $1!' } })
        vim.cmd('set filetype=api')
        main.clear_cache()
        local snippet = main.get_snippets('api').hello
        assert.is_same('Hello, $1!', snippet.body)
        assert.is_same(999, snippet.priority)
        assert.is_same('snipmate', snippet.kind)
    end)

    it('adds table snippets with optional fields and an explicit kind', function()
        main.add_snippets({ api_table = { hello = { body = 'Hello, $1!', kind = 'lsp' } } }, {})
        vim.cmd('set filetype=api_table')
        main.clear_cache()
        local snippet = main.get_snippets('api_table').hello
        assert.is_same('Hello, $1!', snippet.body)
        assert.is_same('lsp', snippet.kind)
        assert.is_same(999, snippet.priority)
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
