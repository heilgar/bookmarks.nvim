--- Autocommand and buffer event handlers for bookmarks.nvim.
-- Handles buffer refresh, highlight, and cleanup logic.
-- @module bookmarks.autocmds
local g = require('bookmarks.globals')
local api, fn, log, defer_fn = g.api, g.fn, g.log, g.defer_fn

local Autocmds = {}
local BookmarkList = require('bookmarks.bookmark_list')
local storage = require('bookmarks.storage')
local nav = require('bookmarks.navigation')
local Decorations = require('bookmarks.decorations')
local Utils = require('bookmarks.utils')

local buffer_bookmarks = {}

--- Get the bookmark list object for a buffer.
-- @param bufnr number: Buffer number.
-- @return table|nil: Bookmark list object or nil.
function Autocmds.get_buffer_bookmarks(bufnr)
    return buffer_bookmarks[bufnr]
end

local function load_buffer_bookmarks(bufnr)
    if Utils.is_special_buff(bufnr) then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local _, filename, _, project_root = nav.get_context()
    local config = require('bookmarks').get_config()
    local branch = nil
    if config.use_branch_specific then
        branch = Utils.get_current_branch()
    end
    local list = config.active_list -- nil for global
    local file_bookmarks = storage.get_file_bookmarks(filename, project_root, branch, list)
    if not file_bookmarks then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local list_obj = BookmarkList.new()
    for _, bookmark in ipairs(file_bookmarks) do
        list_obj:insert_sorted(bookmark)
    end

    buffer_bookmarks[bufnr] = list_obj
    return list_obj
end

--- Refresh bookmark signs and highlights for a buffer.
-- @param bufnr number: Buffer number.
function Autocmds.refresh_buffer(bufnr)
    if Utils.is_special_buff(bufnr) then
        buffer_bookmarks[bufnr] = nil
        return
    end

    local list = load_buffer_bookmarks(bufnr)
    if list then
        defer_fn(function()
            if api.nvim_buf_is_valid(bufnr) then
                Decorations.place_signs(bufnr, list)
                Decorations.highlight_lines(bufnr, list)
            end
        end, 100) -- Defer refresh to ensure signs stay
    end
end

--- Refresh all loaded buffers to update bookmark signs and highlights.
function Autocmds.refresh_all_buffers()
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(bufnr) then
            Autocmds.refresh_buffer(bufnr)
        end
    end
end

local function create_autocmd(event, opts)
    api.nvim_create_autocmd(event, opts)
end

--- Setup autocommands for bookmark events.
function Autocmds.setup()
    local group = api.nvim_create_augroup("BookmarksAutocmds", { clear = true })
    -- Refresh on file write
    create_autocmd("BufWritePost", {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            if vim.bo[bufnr].buftype ~= "" then
                return
            end
            defer_fn(function()
                Autocmds.refresh_buffer(bufnr)
            end, 200)
        end,
    })
    -- Refresh on buffer enter/read
    create_autocmd({ "BufEnter", "BufRead" }, {
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
    create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            for bufnr, _ in pairs(buffer_bookmarks) do
                if api.nvim_buf_is_valid(bufnr) then
                    Autocmds.refresh_buffer(bufnr)
                end
            end
        end,
    })
    -- Clean up on buffer delete
    create_autocmd({ "BufDelete" }, {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            buffer_bookmarks[args.buf] = nil
            if api.nvim_buf_is_valid(bufnr) then
                fn.sign_unplace("bookmarks_group", { buffer = bufnr })
                api.nvim_buf_clear_namespace(bufnr, Decorations.ns_id, 0, -1)
            end
        end,
    })
end

return Autocmds

