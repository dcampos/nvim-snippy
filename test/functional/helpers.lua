local luassert = require('luassert')
local Screen = require('nvim-test.screen')

local ok, helpers = pcall(require, 'nvim-test.helpers')

if not ok then
    error('Failed to load nvim-test helpers')
end

local snippy_src = os.getenv('SNIPPY_PATH') or '.'

local H = helpers

function H.eq(expected, actual, context)
    return luassert.are.same(expected, actual, context)
end

function H.neq(expected, actual, context)
    return luassert.are_not.same(expected, actual, context)
end

H.command = H.api.nvim_command
H.eval = H.api.nvim_eval

H.setup_test_snippets = function()
    H.exec_lua(string.format(
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
        snippy_src .. '/test/snippets/'
    ))
end

H.before_each = function()
    H.clear()
    H.screen = Screen.new(50, 5)

    local defaults = {
        [1] = { foreground = Screen.colors.Blue1, bold = true },
        [2] = { bold = true },
        [3] = { background = Screen.colors.LightGrey },
    }

    if H.fn.has('nvim-0.10') > 0 then
        H.command('colorscheme vim')
        defaults[3] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }
    end

    H.screen:set_default_attr_ids(defaults)

    H.command('language en_US.utf8')
    -- No syntax-based highlighting
    H.command('syntax off')
    -- No tree-siter-based highlighting
    H.exec_lua([[vim.treesitter.start = function() end]])
    -- No matching parentheses highlighting
    H.command('NoMatchParen')
    H.command('set rtp+=' .. snippy_src)
    H.command('runtime plugin/snippy.lua')
    H.command('lua snippy = require("snippy")')
    H.exec_lua([[snippy.setup({ choice_delay = 0 })]])

    H.screen:attach()
end

return H
