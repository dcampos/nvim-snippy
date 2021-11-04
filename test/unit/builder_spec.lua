local Builder = require('snippy.builder')

describe('Builder', function()
    it('resolves comment vars', function()
        -- Reset commentstring to default value
        vim.cmd([[set commentstring&]])
        local builder = Builder.new({ row = 0, col = 0, indent = '', word = '' })
        builder:evaluate_variable({ name = 'BLOCK_COMMENT_START' })
        assert.are.equal('/*', builder.result)
        builder:evaluate_variable({ name = 'BLOCK_COMMENT_END' })
        assert.are.equal('/**/', builder.result)
        builder.result = ''
        builder:evaluate_variable({ name = 'LINE_COMMENT' })
        assert.are.equal('//', builder.result)
    end)

    it('resolves comment vars from commentstring', function()
        vim.cmd([[set commentstring=--%s]])
        local builder = Builder.new({ row = 0, col = 0, indent = '', word = '' })
        builder:evaluate_variable({ name = 'LINE_COMMENT' })
        assert.are.equal('--', builder.result)
        vim.cmd('set commentstring=--[[%s]]')
        builder.result = ''
        builder:evaluate_variable({ name = 'BLOCK_COMMENT_START' })
        assert.are.equal('--[[', builder.result)
        builder:evaluate_variable({ name = 'BLOCK_COMMENT_END' })
        assert.are.equal('--[[]]', builder.result)
    end)
end)
