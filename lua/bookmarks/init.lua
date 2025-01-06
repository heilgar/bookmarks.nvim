local M = {}
local storage = require('bookmarks.storage')

M.ns_id = vim.api.nvim_create_namespace("bookmarks_hl_ns")

local buffer_bookmarks = {}


local function get_context()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return bufnr, filename, line
end

local function load_buffer_bookmarks(bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" or vim.bo[bufnr].buftype ~= "" then
        buffer_bookmarks[bufnr] = nil
        return
    end


    -- print('bookmarks loaded: ', filename)

    local file_bookmarks = storage.get_file_bookmarks(filename)
    buffer_bookmarks[bufnr] = file_bookmarks or {}
end

function M.place_signs_in_buffer(bufnr)
    -- Don’t do anything if the buffer isn’t valid
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local current_filename = vim.api.nvim_buf_get_name(bufnr)
    local bookmarks = buffer_bookmarks[bufnr]

    if not bookmarks or #bookmarks == 0 or current_filename == "" then
        vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })
        return
    end

    -- Clear old signs
    vim.fn.sign_unplace("bookmarks_group", { buffer = bufnr })

    -- Place a sign for each bookmark
    for _, bmk in ipairs(bookmarks) do
        if bmk.filename == current_filename then
            vim.fn.sign_place(
                0,                  -- sign ID 0 => auto-generate
                "bookmarks_group",  -- sign group name
                "BookmarkSign",     -- the sign definition name we created
                bufnr,
                { lnum = bmk.line } -- place sign at this line
            )
        end
    end
end

function M.highlight_bookmarks_in_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)


    local current_filename = vim.api.nvim_buf_get_name(bufnr)
    local bookmarks = buffer_bookmarks[bufnr]
    if not bookmarks or #bookmarks == 0 or current_filename == "" then
        return
    end

    for _, bmk in ipairs(bookmarks) do
        if bmk.filename == current_filename then
            local zero_based_line = bmk.line - 1
            if zero_based_line >= 0 then
                vim.api.nvim_buf_add_highlight(
                    bufnr,
                    M.ns_id,
                    "BookmarkHighlight",
                    zero_based_line,
                    0,
                    -1
                )
            end
        end
    end
end

function M.refresh_bookmarks_in_buffer(bufnr)
    load_buffer_bookmarks(bufnr)
    M.place_signs_in_buffer(bufnr)
    M.highlight_bookmarks_in_buffer(bufnr)
end

function M.add_bookmark()
    local bufnr, filename, line = get_context()
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

    storage.add_bookmark({
        filename = filename,
        line = line,
        content = content,
        timestamp = os.time()
    })

    vim.notify('Bookmark added', vim.log.levels.INFO)

    -- Re‐highlight the current buffer
    M.refresh_bookmarks_in_buffer(bufnr)
end

function M.remove_bookmark()
    local bufnr, filename, line = get_context()
    storage.remove_bookmark(filename, line)

    vim.notify('Bookmark removed', vim.log.levels.INFO)

    -- Re‐highlight the current buffer
    M.refresh_bookmarks_in_buffer(bufnr)
end

function M.jump_to_bookmark(filename, line)
    vim.cmd('edit ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_cursor(0, { line, 0 })

    -- Center the view on the jumped-to line
    vim.cmd('normal! zz')
end

function M.jump_to_next()
    local bufnr, _, line = get_context()

    local bookmarks = buffer_bookmarks[bufnr]
    if not bookmarks or #bookmarks == 0 then
        vim.notify("No bookmarks in file", vim.log.levels.INFO)
        return
    end

    local next_line = nil
    for _, bmk in ipairs(bookmarks) do
        if bmk.line > line and (next_line == nil or bmk.line < next_line) then
            next_line = bmk.line
        end
    end

    if next_line then
        vim.api.nvim_win_set_cursor(0, { next_line, 0 })
        vim.cmd('normal! zz')
    else
        vim.notify("No bookmarks below current line", vim.log.levels.INFO)
    end
end

function M.jump_to_prev()
    local bufnr, _, line = get_context()

    local bookmarks = buffer_bookmarks[bufnr]
    if not bookmarks or #bookmarks == 0 then
        vim.notify("No bookmarks in file", vim.log.levels.INFO)
        return
    end

    local prev_line = nil
    for _, bmk in ipairs(bookmarks) do
        if bmk.line < line and (prev_line == nil or bmk.line > prev_line) then
            prev_line = bmk.line
        end
    end

    if prev_line then
        vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
        vim.cmd('normal! zz')
    else
        vim.notify("No bookmarks above current line", vim.log.levels.INFO)
    end
end

function M.setup(opts)
    opts = opts or {}
    if not storage.setup(opts) then
        return
    end

    if opts.default_mappings ~= false then
        vim.keymap.set('n', '<leader>ba', M.add_bookmark, { desc = 'Add bookmark' })
        vim.keymap.set('n', '<leader>br', M.remove_bookmark, { desc = 'Remove bookmark' })
        vim.keymap.set('n', '<leader>bj', M.jump_to_next, { desc = 'Jump to next bookmark in file' })
        vim.keymap.set('n', '<leader>bk', M.jump_to_prev, { desc = 'Jump to prev bookmark in file' })
        vim.keymap.set('n', '<leader>bl', require('telescope').extensions.bookmarks.list, { desc = 'List bookmarks' })
    elseif opts.mappings then
        if opts.mappings.add then
            vim.keymap.set('n', opts.mappings.add, M.add_bookmark, { desc = 'Add bookmark' })
        end
        if opts.mappings.delete then
            vim.keymap.set('n', opts.mappings.delete, M.remove_bookmark, { desc = 'Remove bookmark' })
        end
        if opts.mappings.list then
            vim.keymap.set('n', opts.mappings.list, require('telescope').extensions.bookmarks.list,
                { desc = 'List bookmarks' })
        end
    end

    vim.api.nvim_set_hl(0, "BookmarkHighlight", {
        bg = "#3a3a3a",
        underline = true
    })

    vim.fn.sign_define("BookmarkSign", {
        text = "",
        texthl = "BookmarkSignHighlight",
        numhl = ""
    })

    local group = vim.api.nvim_create_augroup("BookmarksAutocmds", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufRead" }, {
        callback = function(args)
            -- Refresh the new buffer
            M.refresh_bookmarks_in_buffer(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufDelete" }, {
        group = group,
        callback = function(args)
            buffer_bookmarks[args.buf] = nil
            M.refresh_bookmarks_in_buffer(args.buf)
        end,
    })
end

return M

