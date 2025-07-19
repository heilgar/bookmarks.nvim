--- Main entry point for bookmarks.nvim.
-- Handles configuration, setup, and global state.
-- @module bookmarks
local M = {}

local g = require('bookmarks.globals')
local api, fn, log, defer_fn = g.api, g.fn, g.log, g.defer_fn

-- Plugin configuration
local config = nil
-- Default configuration
local default_config = {
    db_path = fn.stdpath('data') .. '/bookmarks.db',
    use_branch_specific = false, -- Enable/disable branch-specific bookmarks
    default_mappings = true,     -- Enable default keymaps
}


local utils = require('bookmarks.utils')

-- Validate configuration options
local function validate_config(opts)
    if opts.default_scope and not vim.tbl_contains({ "global", "branch" }, opts.default_scope) then
        vim.notify("Invalid default_scope. Must be 'global' or 'branch'", log.levels.WARN)
        opts.default_scope = "global"
    end

    if opts.default_list and type(opts.default_list) ~= "string" then
        vim.notify("Invalid default_list. Must be a string", log.levels.WARN)
        opts.default_list = "main"
    end

    if opts.use_branch_specific then
        if not utils.is_git_repo() then
            vim.notify(
                "[bookmarks.nvim] use_branch_specific is true, but this is not a Git repo. Falling back to global bookmarks.",
                log.levels.WARN)
            opts.use_branch_specific = false
        end
    end
    return opts
end

--- Get the current plugin configuration.
-- @return table: The current configuration table.
function M.get_config()
    return config
end

--- Get the currently active bookmark list name.
-- @return string|nil: The active list name, or nil for global.
function M.get_active_list()
    return config and config.active_list or nil
end

--- Set the active bookmark list.
-- @param list_name string|nil: The list name to activate, or nil for global.
function M.set_active_list(list_name)
    config.active_list = list_name -- nil means global
end

--- Toggle branch-specific bookmark mode on or off.
-- Refreshes all buffers after toggling.
function M.toggle_branch_scope()
    if not config.use_branch_specific then
        -- Turning ON branch-specific mode
        if not utils.is_git_repo() then
            vim.notify("[bookmarks.nvim] Not a Git repo. Cannot enable branch-specific bookmarks. Falling back to global.", log.levels.WARN)
            config.use_branch_specific = false
            require('bookmarks.autocmds').refresh_all_buffers()
            return
        end
        local branch = utils.get_current_branch()
        if not branch or branch == "" then
            vim.notify("[bookmarks.nvim] No valid branch detected. Cannot enable branch-specific bookmarks. Falling back to global.", log.levels.WARN)
            config.use_branch_specific = false
            require('bookmarks.autocmds').refresh_all_buffers()
            return
        end
        config.use_branch_specific = true
        vim.notify("Branch-specific bookmarks: ON (" .. branch .. ")", log.levels.INFO)
    else
        -- Turning OFF branch-specific mode
        config.use_branch_specific = false
        vim.notify("Branch-specific bookmarks: OFF (showing all bookmarks)", log.levels.INFO)
    end
    require('bookmarks.autocmds').refresh_all_buffers()
end

--- Get a status string for the current bookmark scope (for statusline).
-- @return string: Status string indicating current scope and list.
function M.status()
    local status_parts = {}
    
    -- Add branch information
    if config and config.use_branch_specific then
        local branch = utils.get_current_branch()
        if branch and branch ~= "" then
            table.insert(status_parts, "branch=" .. branch)
        else
            table.insert(status_parts, "branch=?")
        end
    else
        table.insert(status_parts, "global")
    end
    
    -- Add list information
    local active_list = config and config.active_list or 'default'
    table.insert(status_parts, "list=" .. active_list)
    
    return "Bookmarks: " .. table.concat(status_parts, ", ")
end

--- Get a short status string for statusline integration.
-- @return string: Short status string.
function M.status_short()
    local active_list = config and config.active_list or 'default'
    local branch_info = ""
    
    if config and config.use_branch_specific then
        local branch = utils.get_current_branch()
        if branch and branch ~= "" then
            branch_info = "(" .. branch .. ") "
        end
    end
    
    return "📖" .. branch_info .. active_list
end

--- Setup the plugin with user configuration.
-- @param opts table: User configuration options.
function M.setup(opts)
    -- Validate and merge user config with defaults
    opts = validate_config(opts or {})
    config = vim.tbl_deep_extend('force', default_config, opts)
    setmetatable(config, { __index = default_config })
    config.active_list = nil -- default to global

    -- Initialize storage with only the storage-specific config
    local storage_config = {
        db_path = config.db_path
    }
    if not require('bookmarks.storage').setup(storage_config) then
        return
    end

    require('bookmarks.decorations').setup(config)
    local autocmds = require('bookmarks.autocmds')
    local keymaps = require('bookmarks.keymaps')
    autocmds.setup()
    keymaps.setup(config, autocmds)

    require('bookmarks.navigation')
end

return M

