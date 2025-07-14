local M = {}

local g = require('bookmarks.globals')
local api, fn, log, defer_fn = g.api, g.fn, g.log, g.defer_fn

local set = api.keymap and api.keymap.set or vim.keymap.set

local function map(mode, lhs, rhs, opts)
    set(mode, lhs, rhs, opts or { noremap = true, silent = true })
end

function M.setup(config, autocmds)
    -- Default keymaps
    if config.default_mappings ~= false then
        map('n', '<leader>ba', function()
            local bufnr = require('bookmarks.commands').add_bookmark()
            autocmds.refresh_buffer(bufnr)
        end, { desc = 'Add bookmark' })

        map('n', '<leader>br', function()
            local bufnr = require('bookmarks.commands').remove_bookmark()
            autocmds.refresh_buffer(bufnr)
        end, { desc = 'Remove bookmark' })

        map('n', '<leader>bj', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bookmarks = autocmds.get_buffer_bookmarks(bufnr)
            require('bookmarks.navigation').jump_to_next(bookmarks)
        end, { desc = 'Jump to next bookmark in file' })

        map('n', '<leader>bk', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bookmarks = autocmds.get_buffer_bookmarks(bufnr)
            require('bookmarks.navigation').jump_to_prev(bookmarks)
        end, { desc = 'Jump to prev bookmark in file' })

        map('n', '<leader>bl', function()
            local telescope = require('telescope')
            telescope.extensions.bookmarks.list()
        end, { desc = 'List bookmarks' })

        map('n', '<leader>bt', function()
            require('bookmarks').toggle_branch_scope()
        end, { desc = 'Toggle branch-specific bookmarks' })

        map('n', '<leader>bs', function()
            local telescope = require('telescope')
            telescope.extensions.bookmarks.lists()
        end, { desc = 'Switch bookmark list' })
    elseif config.mappings then
        if config.mappings.add then
            map('n', config.mappings.add, function()
                local bufnr = require('bookmarks.commands').add_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Add bookmark' })
        end
        if config.mappings.delete then
            map('n', config.mappings.delete, function()
                local bufnr = require('bookmarks.commands').remove_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Remove bookmark' })
        end
        if config.mappings.list then
            map('n', config.mappings.list, function()
                local telescope = require('telescope')
                telescope.extensions.bookmarks.list()
            end, { desc = 'List bookmarks' })
        end
    end
end

return M

