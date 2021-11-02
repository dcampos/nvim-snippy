local snippy = require('snippy')

describe('Snippet reader', function()
    it('can read snippets', function()
        snippy.setup({ snippet_dirs = './test/' })
        vim.cmd('set filetype=')
        local snips = {
            test1 = { kind = 'snipmate', prefix = 'test1', body = { 'This is the first test.' } },
            test2 = { kind = 'snipmate', prefix = 'test2', body = { 'This is the second test.' } },
        }
        assert.is_truthy(require('snippy.shared').config.snippet_dirs)
        assert.is_not.same({}, require('snippy.reader.snipmate').list_available_scopes())
        assert.is_same({ _ = snips }, snippy.snippets)
    end)

    it('can read vim-snippets snippets', function()
        local snippet_dirs = os.getenv('VIM_SNIPPETS_PATH') or './vim-snippets/'
        snippy.setup({
            snippet_dirs = snippet_dirs,
            scopes = {
                _ = function()
                    return { vim.bo.ft }
                end,
            },
        })
        local scopes = require('snippy.reader.snipmate').list_available_scopes()
        assert.is_not.same({}, scopes)
        local total_failed = {}
        local count = 0
        for _, scope in ipairs(scopes) do
            vim.cmd('set filetype=' .. scope)
            local snips = snippy.snippets
            assert.is_not.equal(nil, snips[scope])
            local failed = {}
            for _, snip in pairs(snippy.snippets[scope]) do
                local text = table.concat(snip.body, '\n')
                local ok, _, pos = require('snippy.parser').parse_snipmate(text, 1)
                if not ok or pos ~= #text + 1 then
                    table.insert(failed, { snip, ok, pos, #text + 1 })
                end
                count = count + 1
            end
            if #failed > 0 then
                total_failed[scope] = failed
                break
            end
        end
        assert.is_same({}, total_failed)
    end)
end)
