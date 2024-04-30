local luassert = require('luassert')
local Screen = require('test.functional.ui.screen')

local ok, helpers = pcall(require, 'test.functional.testnvim')
if not ok then
    ok, helpers = pcall(require, 'test.functional.helpers')
end

local snippy_src = os.getenv('SNIPPY_PATH') or '.'

local H = helpers()

function H.eq(expected, actual, context)
    return luassert.are.same(expected, actual, context)
end

function H.neq(expected, actual, context)
    return luassert.are_not.same(expected, actual, context)
end

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
        H.alter_slashes(snippy_src .. '/test/snippets/')
    ))
end

H.before_each = function()
    H.clear()
    H.screen = Screen.new(50, 5)
    H.screen:attach()

    local defaults = {
        [1] = { foreground = Screen.colors.Blue1, bold = true },
        [2] = { bold = true },
        [3] = { background = Screen.colors.LightGrey },
    }

    if H.eval('has("nvim-0.10")') > 0 then
        H.command('colorscheme vim')
        defaults[3] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }
    end

    H.screen:set_default_attr_ids(defaults)

    H.command('set rtp=$VIMRUNTIME')
    H.command('set rtp+=' .. H.alter_slashes(snippy_src))
    H.command('runtime plugin/snippy.lua')
    H.command('lua snippy = require("snippy")')
    H.exec_lua([[snippy.setup({ choice_delay = 0 })]])
end

return H
