local Utils = {}

function Utils.debug_print(msg)
    print(string.format("[Bookmarks Debug] %s", msg))
end

function Utils.is_special_buff(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return true
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    local btype = vim.bo[bufnr].buftype

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

function Utils.is_git_repo()
    return handle_git_command("git rev-parse --is-inside-work-tree")
end

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

