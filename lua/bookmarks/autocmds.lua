local Autocmds = {}
local BookmarkList = require('bookmarks.bookmark_list')
local storage = require('bookmarks.storage')
local Navigation = require('bookmarks.navigation')
local Decorations = require('bookmarks.decorations')
local Utils = require('bookmarks.utils')

local buffer_bookmarks = {}

function Autocmds.get_buffer_bookmarks(bufnr)
    return buffer_bookmarks[bufnr]
end

local function load_buffer_bookmarks(bufnr)
    if Utils.is_special_buff(bufnr) then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local _, filename, _, project_root = Navigation.get_context()
    local config = require('bookmarks').get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = Utils.get_current_branch()
    end
    local file_bookmarks = storage.get_file_bookmarks(filename, project_root, branch)
    if not file_bookmarks then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local list = BookmarkList.new()
    for _, bookmark in ipairs(file_bookmarks) do
        list:insert_sorted(bookmark)
    end

    buffer_bookmarks[bufnr] = list
    return list
end

function Autocmds.refresh_buffer(bufnr)
    if Utils.is_special_buff(bufnr) then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local list = load_buffer_bookmarks(bufnr)
    if list then
        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                -- Utils.debug_print(string.format("Deferred sign refresh for buffer %d", bufnr))
                Decorations.place_signs(bufnr, list)
                Decorations.highlight_lines(bufnr, list)
            end
        end, 100) -- Defer refresh to ensure signs stay
    end
end

function Autocmds.refresh_all_buffers()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            Autocmds.refresh_buffer(bufnr)
        end
    end
end

function Autocmds.setup()
    local group = vim.api.nvim_create_augroup("BookmarksAutocmds", { clear = true })
    -- Refresh on file write
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            if vim.bo[bufnr].buftype ~= "" then
                return
            end

            vim.defer_fn(function()
                Autocmds.refresh_buffer(bufnr)
            end, 200)
        end,
    })
    -- Refresh on buffer enter/read
    vim.api.nvim_create_autocmd({ "BufEnter", "BufRead" }, {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            if vim.bo[bufnr].buftype ~= "" then
                return
            end
            Autocmds.refresh_buffer(args.buf)
        end,
    })
    -- Refresh on colorscheme change
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            -- Reapply highlights for all valid buffers
            for bufnr, _ in pairs(buffer_bookmarks) do
                if vim.api.nvim_buf_is_valid(bufnr) then
                    Autocmds.refresh_buffer(bufnr)
                end
            end
        end,
    })
    -- Clean up on buffer delete
    vim.api.nvim_create_autocmd({ "BufDelete" }, {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            buffer_bookmarks[args.buf] = nil

            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })
                vim.api.nvim_buf_clear_namespace(bufnr, Decorations.ns_id, 0, -1)
            end
        end,
    })
end

return Autocmds

