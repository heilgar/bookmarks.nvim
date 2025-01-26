local Commands = {}
local Navigation = require('bookmarks.navigation')
local storage = require('bookmarks.storage')

function Commands.add_bookmark()
    local bufnr, filename, line, project_root = Navigation.get_context()
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

    storage.add_bookmark({
        filename = filename,
        line = line,
        content = content,
        timestamp = os.time(),
        project_root = project_root,
    })

    vim.notify('Bookmark added', vim.log.levels.INFO)
    return bufnr
end

function Commands.remove_bookmark()
    local bufnr, filename, line, project_root = Navigation.get_context()
    storage.remove_bookmark(filename, line, project_root)

    vim.notify('Bookmark removed', vim.log.levels.INFO)
    return bufnr
end

return Commands

