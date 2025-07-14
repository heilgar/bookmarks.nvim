local Commands = {}
local Navigation = require('bookmarks.navigation')
local storage = require('bookmarks.storage')
local utils = require('bookmarks.utils')

function Commands.add_bookmark()
    local bufnr, filename, line, project_root = Navigation.get_context()
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

    local config = require('bookmarks').get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = utils.get_current_branch()
    end

    storage.add_bookmark({
        filename = filename,
        line = line,
        content = content,
        timestamp = os.time(),
        project_root = project_root,
        branch = branch,
    })

    vim.notify('Bookmark added', vim.log.levels.INFO)
    return bufnr
end

function Commands.remove_bookmark()
    local bufnr, filename, line, project_root = Navigation.get_context()
    local config = require('bookmarks').get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = utils.get_current_branch()
    end
    storage.remove_bookmark(filename, line, project_root, branch)

    vim.notify('Bookmark removed', vim.log.levels.INFO)
    return bufnr
end

return Commands

