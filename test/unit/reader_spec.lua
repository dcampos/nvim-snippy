local snippy = require('snippy')

describe('Snippet reader', function()
    before_each(function()
        snippy.clear_cache()
    end)

    it('can read snippets', function()
        snippy.setup({ snippet_dirs = './test/snippets/' })
        vim.cmd('set filetype=')
        local snips = {
            test1 = { kind = 'snipmate', prefix = 'test1', option = '', body = { 'This is the first test.' } },
            test2 = { kind = 'snipmate', prefix = 'test2', option = '', body = { 'This is the second test.' } },
        }
        assert.is_truthy(require('snippy.shared').config.snippet_dirs)
        assert.is_not.same({}, require('snippy.reader.snipmate').list_available_scopes())
        assert.is_same({ _ = snips }, snippy.snippets)
    end)

    it('can read *.snippet files', function()
        snippy.setup({ snippet_dirs = './test/snippets/' })
        vim.cmd('set filetype=php')
        local snips = {
            no_description = {
                kind = 'snipmate',
                prefix = 'no_description',
                body = {
                    'This is a *.snippet file with no description.',
                },
            },
            trigger = {
                kind = 'snipmate',
                prefix = 'trigger',
                description = 'description',
                body = {
                    'This is a *.snippet file with a description.',
                },
            },
        }
        assert.is_not.same({}, require('snippy.reader.snipmate').list_available_scopes())
        assert.is_same(snips, snippy.snippets.php)
    end)

    it('can read snippets with custom indent', function()
        snippy.setup({ snippet_dirs = './test/snippets/' })
        vim.cmd('set filetype=custom')
        local snips = {
            trigger = {
                kind = 'snipmate',
                prefix = 'trigger',
                option = '',
                body = {
                    'This is indented with two spaces.',
                    '\tThis is indented with four spaces.',
                    '\t\tThis is indented with eight spaces.',
                },
            },
        }
        assert.is_truthy(require('snippy.shared').config.snippet_dirs)
        assert.is_not.same({}, require('snippy.reader.snipmate').list_available_scopes())
        assert.is_same(snips, snippy.snippets.custom)
    end)

    it('can read vim-snippets snippets', function()
        local snippet_dirs = os.getenv('VIM_SNIPPETS_PATH') or './vim-snippets/snippets/'
        snippy.setup({
            snippet_dirs = snippet_dirs,
            scopes = {
                _ = function()
                    return { #vim.bo.ft > 0 and vim.bo.ft or '_' }
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
