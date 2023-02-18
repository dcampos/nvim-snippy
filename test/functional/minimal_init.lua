vim.cmd([[let &rtp.=','.getcwd()]])

if #vim.api.nvim_list_uis() == 0 then
    vim.cmd('set rtp+=.deps/mini.test')

    require('mini.test').setup({
        collect = {
            find_files = function()
                return vim.fn.globpath('test/functional', '**/test_*.lua', true, true)
            end,
        },
    })
end
