local parser = require('snippy.parser')

describe('Parser', function()
    it('Parse a basic snippet', function()
        local snip = 'local $1 = ${2}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({ type = 'tabstop', id = 2, children = {} }, result[#result])
    end)
    it('Parse a nested placeholder', function()
        local snip = 'local ${1} = ${2:${3:bar}}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same(result[#result], {
            type = 'placeholder',
            id = 2,
            children = {
                {
                    type = 'placeholder',
                    id = 3,
                    children = {
                        { type = 'text', escaped = 'bar', raw = 'bar' },
                    },
                },
            },
        })
    end)
    it('Parse a choice stop', function()
        local snip = 'local ${1} = ${2|option1, option2, option3|}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same(
            { type = 'choice', id = 2, children = { [1] = 'option1' }, choices = { 'option1', 'option2', 'option3' } },
            result[#result]
        )
    end)
    it('Parse an empty placeholder', function()
        local snip = '${1:} = ${0:}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({ type = 'placeholder', id = 1, children = {} }, result[1])
    end)
    it('Parse a transform tabstop', function()
        local snip = 'local ${1} = ${2/foo/bar/ig}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({
            type = 'tabstop',
            id = 2,
            children = {},
            transform = {
                type = 'transform',
                flags = 'ig',
                regex = 'foo',
                format = 'bar',
            },
        }, result[#result])
    end)
    it('Parse a transform without flags', function()
        local snip = 'local ${1} = ${2/foo/bar}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({
            type = 'tabstop',
            id = 2,
            children = {},
            transform = {
                type = 'transform',
                flags = '',
                regex = 'foo',
                format = 'bar',
            },
        }, result[#result])
    end)
    it('Parse a transform with empty replacement', function()
        local snip = 'local ${1} = ${2/foo//g}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        local t = result[#result]
        assert.is_same('foo', t.transform.regex)
        assert.is_same('', t.transform.format)
        assert.is_same('g', t.transform.flags)
    end)
    it('Parse variables', function()
        local snip = 'local ${1} = ${TM_CURRENT_YEAR}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({ type = 'variable', name = 'TM_CURRENT_YEAR', children = {} }, result[#result])
    end)
    it('Parse variables with children', function()
        local snip = 'local ${1} = ${TM_CURRENT_YEAR:1992}'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({
            type = 'variable',
            name = 'TM_CURRENT_YEAR',
            children = { [1] = { type = 'text', raw = '1992', escaped = '1992' } },
        }, result[#result])
    end)
    it('Parse single ending character', function()
        local snip = 'local ${1} = "${2:snip}"'
        local ok, result, pos = parser.parse(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({ type = 'text', raw = '"', escaped = '"' }, result[#result])
    end)
    it('Parse SnipMate eval', function()
        local snip = 'local ${1} = `g:snips_author`'
        local ok, result, pos = parser.parse_snipmate(snip, 1)
        assert.is_true(ok)
        assert.is_same(pos, #snip + 1)
        assert.is_same({
            type = 'eval',
            children = { [1] = { type = 'text', raw = 'g:snips_author', escaped = 'g:snips_author' } },
        }, result[#result])
    end)
end)
