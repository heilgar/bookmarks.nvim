local Navigation = {}

function Navigation.get_context()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local project_root = vim.fn.getcwd()

    return bufnr, filename, line, project_root
end

function Navigation.jump_to_bookmark(filename, line)
    vim.cmd('edit ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.cmd('normal! zz')
end

function Navigation.jump_to_next(bookmarks)
    if not bookmarks or bookmarks:is_empty() then
        vim.notify("No bookmarks in file", vim.log.levels.INFO)
        return
    end

    local _, _, line = Navigation.get_context()
    local next_bmk = bookmarks:find_next(line)
    if next_bmk then
        vim.api.nvim_win_set_cursor(0, { next_bmk.line, 0 })
        vim.cmd('normal! zz')
    else
        vim.notify("No bookmarks below current line", vim.log.levels.INFO)
    end
end

function Navigation.jump_to_prev(bookmarks)
    if not bookmarks or bookmarks:is_empty() then
        vim.notify("No bookmarks in file", vim.log.levels.INFO)
        return
    end

    local _, _, line = Navigation.get_context()
    local prev_bmk = bookmarks:find_prev(line)
    if prev_bmk then
        vim.api.nvim_win_set_cursor(0, { prev_bmk.line, 0 })
        vim.cmd('normal! zz')
    else
        vim.notify("No bookmarks above current line", vim.log.levels.INFO)
    end
end

return Navigation

