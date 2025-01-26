local Autocmds = {}
local BookmarkList = require('bookmarks.bookmark_list')
local storage = require('bookmarks.storage')
local Navigation = require('bookmarks.navigation')
local Decorations = require('bookmarks.decorations')
-- local Utils = require('bookmarks.utils')

local buffer_bookmarks = {}

function Autocmds.get_buffer_bookmarks(bufnr)
    return buffer_bookmarks[bufnr]
end

local function load_buffer_bookmarks(bufnr)
    local _, filename, _, project_root = Navigation.get_context()
    -- Utils.debug_print(string.format("Loading bookmarks for buffer %d, file: %s", bufnr, filename))

    if filename == "" or vim.bo[bufnr].buftype ~= "" then
        -- Utils.debug_print(string.format("Skipping buffer %d (empty filename or special buffer)", bufnr))
        buffer_bookmarks[bufnr] = nil
        return
    end

    local file_bookmarks = storage.get_file_bookmarks(filename, project_root)
    if not file_bookmarks then
        -- Utils.debug_print(string.format("No bookmarks found for buffer %d", bufnr))
        buffer_bookmarks[bufnr] = nil
        return
    end

    local list = BookmarkList.new()
    for _, bookmark in ipairs(file_bookmarks) do
        list:insert_sorted(bookmark)
    end

    buffer_bookmarks[bufnr] = list
    -- Utils.debug_print(string.format("Loaded %d bookmarks for buffer %d", #list.items, bufnr))
    return list
end

function Autocmds.refresh_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        -- Utils.debug_print(string.format("Buffer %d is not valid", bufnr))
        return
    end

    -- Skip special buffers
    if vim.bo[bufnr].buftype ~= "" then
        -- Utils.debug_print(string.format("Skipping special buffer %d", bufnr))
        return
    end

    local list = load_buffer_bookmarks(bufnr)
    if list then
        -- Utils.debug_print(string.format("Signs about to be placed for buffer %d", bufnr))
        Decorations.place_signs(bufnr, list)
        Decorations.highlight_lines(bufnr, list)
        -- Utils.debug_print(string.format("Signs placed for buffer %d", bufnr))
        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                -- Utils.debug_print(string.format("Deferred sign refresh for buffer %d", bufnr))
                Decorations.place_signs(bufnr, list)
                Decorations.highlight_lines(bufnr, list)
            end
        end, 100) -- Defer refresh to ensure signs stay
    end
end

function Autocmds.setup()
    local group = vim.api.nvim_create_augroup("BookmarksAutocmds", { clear = true })
    -- vim.api.nvim_create_autocmd("BufWritePost", {
    --     group = group,
    --     callback = function(args)
    --         local bufnr = args.buf
    --         -- Utils.debug_print(string.format("BufWritePost triggered for buffer %d", bufnr))
    --         if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "NvimTree" then
    --             return
    --         end
    --         -- Refresh immediately
    --         Autocmds.refresh_buffer(bufnr)
    --         -- And schedule another refresh
    --         vim.defer_fn(function()
    --             if vim.api.nvim_buf_is_valid(bufnr) then
    --                 Autocmds.refresh_buffer(bufnr)
    --             end
    --         end, 50)
    --     end,
    -- })
    -- Refresh on file write
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            if vim.bo[bufnr].buftype ~= "" then
                return
            end
            Autocmds.refresh_buffer(bufnr)
        end,
    })
    -- vim.api.nvim_create_autocmd({ "BufEnter", "BufRead" }, {
    --     group = group,
    --     callback = function(args)
    --         local bufnr = args.buf
    --         -- Skip special buffers (including NvimTree)
    --         if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "NvimTree" then
    --             -- Utils.debug_print(string.format("Skipping special buffer/filetype %d", bufnr))
    --             return
    --         end
    --
    --         Autocmds.refresh_buffer(args.buf)
    --     end,
    -- })
    --
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

    -- vim.api.nvim_create_autocmd({ "BufDelete" }, {
    --     group = group,
    --     callback = function(args)
    --         local bufnr = args.buf
    --         -- Utils.debug_print(string.format("Buffer %d left/deleted, cleaning up", bufnr))
    --         buffer_bookmarks[args.buf] = nil
    --
    --         -- Clear signs and highlights when leaving buffer
    --         if vim.api.nvim_buf_is_valid(bufnr) then
    --             vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })
    --             vim.api.nvim_buf_clear_namespace(bufnr, Decorations.ns_id, 0, -1)
    --         end
    --     end,
    -- })
    --
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

