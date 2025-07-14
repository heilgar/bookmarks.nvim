--- User-facing commands for bookmarks.nvim.
-- Implements add, remove, list, and list management commands.
-- @module bookmarks.commands
local Commands = {}
local g = require('bookmarks.globals')
local api, fn, log, defer_fn = g.api, g.fn, g.log, g.defer_fn

local nav = require('bookmarks.navigation')
local storage = require('bookmarks.storage')
local utils = require('bookmarks.utils')
local init = require('bookmarks')

local function notify(msg, level)
    api.nvim_notify(msg, level or log.levels.INFO, {})
end

--- Add a bookmark at the current line in the current buffer.
-- @return number: The buffer number where the bookmark was added.
function Commands.add_bookmark()
    local bufnr, filename, line, project_root = nav.get_context()
    local content = api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

    local config = init.get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = utils.get_current_branch()
    end
    local list = config.active_list -- nil for global
    -- When 'all' is selected, add bookmarks to default list
    if list == 'all' then
        list = nil
    end

    -- Check if a bookmark already exists at this line
    if storage.bookmark_exists(filename, line, project_root, branch, list) then
        notify('Bookmark already exists at this line', log.levels.WARN)
        return bufnr
    end

    storage.add_bookmark({
        filename = filename,
        line = line,
        content = content,
        timestamp = os.time(),
        project_root = project_root,
        branch = branch,
        list = list,
    })

    notify('Bookmark added')
    return bufnr
end

--- Remove a bookmark at the current line in the current buffer.
-- @return number: The buffer number where the bookmark was removed.
function Commands.remove_bookmark()
    local bufnr, filename, line, project_root = nav.get_context()
    local config = init.get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = utils.get_current_branch()
    end
    local list = config.active_list -- nil for global
    -- When 'all' is selected, we need to find and remove the bookmark from its actual list
    if list == 'all' then
        -- Get all bookmarks for this file/line to find the actual list
        local all_bookmarks = storage.get_file_bookmarks(filename, project_root, branch, list)
        for _, bmk in ipairs(all_bookmarks) do
            if bmk.line == line then
                -- Remove from the bookmark's actual list
                storage.remove_bookmark(filename, line, project_root, branch, bmk.list)
                notify('Bookmark removed')
                return bufnr
            end
        end
        notify('Bookmark not found', log.levels.ERROR)
        return bufnr
    end
    storage.remove_bookmark(filename, line, project_root, branch, list)

    notify('Bookmark removed')
    return bufnr
end

--- Create a new bookmark list.
-- @param name string: Name of the new list.
function Commands.create_list(name)
    if not name or name == '' then
        notify('List name required', log.levels.ERROR)
        return
    end
    if name == 'default' then
        notify('Cannot create a list named "default"', log.levels.ERROR)
        return
    end
    if storage.create_list(name) then
        notify('Created bookmark list: ' .. name)
    else
        notify('Failed to create list (maybe already exists?)', log.levels.ERROR)
    end
end

--- Switch to a different bookmark list.
-- @param name string|nil: Name of the list to switch to, or nil for global.
function Commands.switch_list(name)
    if name == 'default' then name = nil end
    local lists = storage.get_lists()
    local found = false
    for _, l in ipairs(lists) do
        if l.name == (name or 'default') or (name == 'all' and l.name == 'all') then found = true break end
    end
    if not found and name ~= 'all' then
        notify('List not found: ' .. (name or 'default'), log.levels.ERROR)
        return
    end
    init.set_active_list(name)
    notify('Switched to bookmark list: ' .. (name or 'default'))
    require('bookmarks.autocmds').refresh_all_buffers()
end

--- Rename a bookmark list.
-- @param old_name string: Old list name.
-- @param new_name string: New list name.
function Commands.rename_list(old_name, new_name)
    if not old_name or not new_name or old_name == '' or new_name == '' then
        notify('Usage: BookmarkListRename <old> <new>', log.levels.ERROR)
        return
    end
    if old_name == 'default' or new_name == 'default' then
        notify('Cannot rename to or from "default"', log.levels.ERROR)
        return
    end
    if storage.rename_list(old_name, new_name) then
        notify('Renamed list: ' .. old_name .. ' → ' .. new_name)
        -- If active, update
        local config = init.get_config()
        if config.active_list == old_name then
            init.set_active_list(new_name)
        end
    else
        notify('Failed to rename list', log.levels.ERROR)
    end
end

--- Delete a bookmark list.
-- @param name string: Name of the list to delete.
function Commands.delete_list(name)
    if not name or name == '' then
        notify('List name required', log.levels.ERROR)
        return
    end
    if name == 'default' then
        notify('Cannot delete the default list', log.levels.ERROR)
        return
    end
    -- Default: reassign bookmarks to default
    if storage.delete_list(name, { reassign_to_default = true }) then
        notify('Deleted list: ' .. name .. ' (bookmarks moved to default)')
        local config = init.get_config()
        if config.active_list == name then
            init.set_active_list(nil)
            require('bookmarks.autocmds').refresh_all_buffers()
        end
    else
        notify('Failed to delete list', log.levels.ERROR)
    end
end

--- Show all bookmark lists, marking the active one.
function Commands.show_lists()
    local lists = storage.get_lists()
    local config = init.get_config()
    local active = config.active_list or 'default'
    local msg = 'Bookmark Lists:\n'
    msg = msg .. (active == 'all' and '  * all (active)\n' or '    all\n')
    for _, l in ipairs(lists) do
        if l.name == active then
            msg = msg .. '  * ' .. l.name .. ' (active)\n'
        else
            msg = msg .. '    ' .. l.name .. '\n'
        end
    end
    notify(msg)
end

--- Show current bookmark status (branch and list).
function Commands.show_status()
    local status = init.status()
    notify(status)
end

return Commands

