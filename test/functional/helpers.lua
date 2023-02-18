local H = {}

H.expect = vim.deepcopy(MiniTest.expect)

H.eq = H.expect.equality
H.neq = H.expect.no_equality

-- Monkey-patch `MiniTest.new_child_neovim` with helpful wrappers
H.new_child_neovim = function()
    local child = MiniTest.new_child_neovim()

    local prevent_hanging = function(method)
        -- stylua: ignore
        if not child.is_blocked() then return end

        local msg = string.format('Can not use `child.%s` because child process is blocked.', method)
        error(msg)
    end

    child.count = 0

    child.set_lines = function(arr, start, finish)
        prevent_hanging('set_lines')

        if type(arr) == 'string' then
            arr = vim.split(arr, '\n')
        end

        child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
    end

    child.get_lines = function(start, finish)
        prevent_hanging('get_lines')

        return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
    end

    child.expect_lines = function(lines)
        MiniTest.expect.equality(child.get_lines(), lines)
    end

    child.set_cursor = function(line, column, win_id)
        prevent_hanging('set_cursor')

        child.api.nvim_win_set_cursor(win_id or 0, { line, column })
    end

    child.get_cursor = function(win_id)
        prevent_hanging('get_cursor')

        return child.api.nvim_win_get_cursor(win_id or 0)
    end

    child.set_size = function(lines, columns)
        prevent_hanging('set_size')

        if type(lines) == 'number' then
            child.o.lines = lines
        end

        if type(columns) == 'number' then
            child.o.columns = columns
        end
    end

    child.get_size = function()
        prevent_hanging('get_size')

        return { child.o.lines, child.o.columns }
    end

    child.expect_screenshot = function(opts, path, screenshot_opts)
        MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path or child.shot_path(), opts)
    end

    child.shot_path = function()
        child.count = child.count + 1
        local desc = MiniTest.current.case.desc
        local id = string.format('%s_%02d_%s', desc[1], child.count, table.concat(vim.list_slice(desc, 2, #desc), '_'))
        id = id:gsub('[^%w_]', '-')
        return string.format('test/functional/screenshots/%s.txt', id)
    end

    return child
end

return H
