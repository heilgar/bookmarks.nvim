local M = {}

-- Plugin configuration
local config = nil

-- Default configuration
local default_config = {
    db_path = vim.fn.stdpath('data') .. '/bookmarks.db',
    use_branch_specific = false, -- Enable/disable branch-specific bookmarks
    default_mappings = true,     -- Enable default keymaps
}

-- Validate configuration options
local function validate_config(opts)
    if opts.default_scope and not vim.tbl_contains({ "global", "branch" }, opts.default_scope) then
        vim.notify("Invalid default_scope. Must be 'global' or 'branch'", vim.log.levels.WARN)
        opts.default_scope = "global"
    end

    if opts.default_list and type(opts.default_list) ~= "string" then
        vim.notify("Invalid default_list. Must be a string", vim.log.levels.WARN)
        opts.default_list = "main"
    end

    if opts.use_branch_specific then
        local utils = require('bookmarks.utils')
        if not utils.is_git_repo() then
            vim.notify(
                "[bookmarks.nvim] use_branch_specific is true, but this is not a Git repo. Falling back to global bookmarks.",
                vim.log.levels.WARN)
            opts.use_branch_specific = false
        end
    end
    return opts
end

-- Get current configuration
function M.get_config()
    return config
end

function M.toggle_branch_scope()
    local utils = require('bookmarks.utils')
    if not config.use_branch_specific then
        -- Turning ON branch-specific mode
        if not utils.is_git_repo() then
            vim.notify("[bookmarks.nvim] Not a Git repo. Cannot enable branch-specific bookmarks. Falling back to global.", vim.log.levels.WARN)
            config.use_branch_specific = false
            require('bookmarks.autocmds').refresh_all_buffers()
            return
        end
        local branch = utils.get_current_branch()
        if not branch or branch == "" then
            vim.notify("[bookmarks.nvim] No valid branch detected. Cannot enable branch-specific bookmarks. Falling back to global.", vim.log.levels.WARN)
            config.use_branch_specific = false
            require('bookmarks.autocmds').refresh_all_buffers()
            return
        end
        config.use_branch_specific = true
        vim.notify("Branch-specific bookmarks: ON (" .. branch .. ")", vim.log.levels.INFO)
    else
        -- Turning OFF branch-specific mode
        config.use_branch_specific = false
        vim.notify("Branch-specific bookmarks: OFF (showing all bookmarks)", vim.log.levels.INFO)
    end
    require('bookmarks.autocmds').refresh_all_buffers()
end

function M.status()
    local utils = require('bookmarks.utils')
    if config and config.use_branch_specific then
        local branch = utils.get_current_branch()
        if branch and branch ~= "" then
            return "Bookmarks: branch=" .. branch
        else
            return "Bookmarks: branch=?"
        end
    else
        return "Bookmarks: global"
    end
end

function M.setup(opts)
    -- Validate and merge user config with defaults
    opts = validate_config(opts or {})
    config = vim.tbl_deep_extend('force', default_config, opts)

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

