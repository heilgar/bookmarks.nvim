--- Utility functions for bookmarks.nvim.
-- Miscellaneous helpers for buffer and git operations.
-- @module bookmarks.utils
local g = require('bookmarks.globals')
local api, fn, bo, log, defer_fn = g.api, g.fn, g.bo, g.log, g.defer_fn

local Utils = {}

--- Print a debug message for bookmarks.nvim.
-- @param msg string: The debug message to print.
function Utils.debug_print(msg)
    print(string.format("[Bookmarks Debug] %s", msg))
end

--- Check if a buffer is a special (non-file) buffer.
-- @param bufnr number: Buffer number to check.
-- @return boolean: True if special, false otherwise.
function Utils.is_special_buff(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return true
    end

    local name = api.nvim_buf_get_name(bufnr)
    local btype = bo[bufnr].buftype

    -- Skip if name is empty, "true", or this buffer has a non-empty buftype.
    -- (Common special buftypes are: "help", "prompt", "terminal", "quickfix", etc.)
    if name == "" or name == "true" or btype ~= "" then
        return true
    end

    -- detect other patterns, e.g. "term://", "dap-repl://", etc.
    if name:match("^term://") then
        return true
    end
end

local function handle_git_command(command)
    local handle = io.popen(command .. " 2>/dev/null")
    if handle then
        local result = handle:read("*l")
        handle:close()
        return result and result == "true"
    end
end

--- Check if the current working directory is a Git repository.
-- @return boolean: True if inside a Git repo, false otherwise.
function Utils.is_git_repo()
    return handle_git_command("git rev-parse --is-inside-work-tree")
end

--- Get the current Git branch name.
-- @return string|nil: The current branch name, or nil if not in a Git repo.
function Utils.get_current_branch()
    local handle = io.popen("git branch --show-current -i 2>/dev/null")
    if handle then
        local branch = handle:read("*l")
        handle:close()
        return branch and branch ~= "" and branch or nil
    end
    return nil
end

return Utils

