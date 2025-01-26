local Decorations = {}
-- local Utils = require('bookmarks.utils')

Decorations.ns_id = vim.api.nvim_create_namespace("bookmarks_hl_ns")

function Decorations.setup(opts)
    vim.api.nvim_set_hl(0, "BookmarkHighlight", {
        bg = "#594d3e",
        sp = "#FFE5B4",
        bold = true,
        underline = false,
        default = true,
        cterm = {
            bold = true,
            underline = true,
        }
    })

    vim.api.nvim_set_hl(0, "BookmarkSignHighlight", {
        fg = opts.sign_fg or "#FFE5B4",
        bold = true,
        default = true,
        cterm = {
            bold = true,
        }
    })

    vim.fn.sign_define("BookmarkSign", {
        text = "",
        texthl = "BookmarkSignHighlight",
        numhl = "BookmarkSignHighlight",
        linehl = "BookmarkHighlight",
        hl_mode = "combine", -- or "replace"
    })
    local hl_exists = vim.api.nvim_get_hl(0, { name = "BookmarkHighlight" })
    -- Utils.debug_print("BookmarkHighlight definition:", vim.inspect(hl_exists))
end

function Decorations.place_signs(bufnr, bookmarks)
    -- Utils.debug_print(string.format("Placing signs for buffer %d", bufnr))
    if not vim.api.nvim_buf_is_valid(bufnr) then
        -- Utils.debug_print(string.format("Buffer %d is not valid", bufnr))
        return
    end

    local current_filename = vim.api.nvim_buf_get_name(bufnr)
    -- Handle both BookmarkList and array formats
    local bookmark_array = bookmarks.items or bookmarks

    if not bookmark_array or #bookmark_array == 0 or current_filename == "" then
        -- Utils.debug_print("No bookmarks to place signs for")
        vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })
        return
    end

    -- Clear old signs
    vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })

    -- Place signs
    for _, bmk in ipairs(bookmark_array) do
        if bmk.filename == current_filename and
            bmk.line > 0 and
            bmk.line <= vim.api.nvim_buf_line_count(bufnr) then
            vim.fn.sign_place(
                0,
                "bookmarks_group",
                "BookmarkSign",
                bufnr,
                {
                    lnum = bmk.line,
                    priority = 10
                }
            )
        end
    end
end

function Decorations.highlight_lines(bufnr, bookmarks)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_buf_clear_namespace(bufnr, Decorations.ns_id, 0, -1)

    local bookmark_array = bookmarks.items or bookmarks
    if not bookmark_array or #bookmark_array == 0 then
        return
    end

    local current_filename = vim.api.nvim_buf_get_name(bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Utils.debug_print("Starting line highlight")

    for _, bmk in ipairs(bookmark_array) do
        -- Utils.debug_print(string.format("Highlighting line %d in file %s", bmk.line, bmk.filename))
        if bmk.filename == current_filename then
            local zero_based_line = bmk.line - 1
            if zero_based_line >= 0 and zero_based_line < line_count then
                vim.api.nvim_buf_add_highlight(
                    bufnr,
                    Decorations.ns_id,
                    "BookmarkHighlight",
                    zero_based_line,
                    0,
                    -1
                )
                -- Utils.debug_print(string.format("Added highlight at line %d", bmk.line))
            end
        end
    end
end

return Decorations

