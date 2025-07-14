local M = {}

function M.setup(config, autocmds)
    -- Default keymaps
    if config.default_mappings ~= false then
        vim.keymap.set('n', '<leader>ba', function()
            local bufnr = require('bookmarks.commands').add_bookmark()
            autocmds.refresh_buffer(bufnr)
        end, { desc = 'Add bookmark' })

        vim.keymap.set('n', '<leader>br', function()
            local bufnr = require('bookmarks.commands').remove_bookmark()
            autocmds.refresh_buffer(bufnr)
        end, { desc = 'Remove bookmark' })

        vim.keymap.set('n', '<leader>bj', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bookmarks = autocmds.get_buffer_bookmarks(bufnr)
            require('bookmarks.navigation').jump_to_next(bookmarks)
        end, { desc = 'Jump to next bookmark in file' })

        vim.keymap.set('n', '<leader>bk', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bookmarks = autocmds.get_buffer_bookmarks(bufnr)
            require('bookmarks.navigation').jump_to_prev(bookmarks)
        end, { desc = 'Jump to prev bookmark in file' })

        vim.keymap.set('n', '<leader>bl',
            require('telescope').extensions.bookmarks.list,
            { desc = 'List bookmarks' }
        )

        vim.keymap.set('n', '<leader>bt', function()
            require('bookmarks').toggle_branch_scope()
        end, { desc = 'Toggle branch-specific bookmarks' })
    elseif config.mappings then
        -- Custom mappings setup
        if config.mappings.add then
            vim.keymap.set('n', config.mappings.add, function()
                local bufnr = require('bookmarks.commands').add_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Add bookmark' })
        end
        if config.mappings.delete then
            vim.keymap.set('n', config.mappings.delete, function()
                local bufnr = require('bookmarks.commands').remove_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Remove bookmark' })
        end
        if config.mappings.list then
            vim.keymap.set('n', config.mappings.list,
                require('telescope').extensions.bookmarks.list,
                { desc = 'List bookmarks' }
            )
        end
    end
end

return M

