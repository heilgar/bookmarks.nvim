local M = {}


function M.setup(opts)
    opts = opts or {}
    if not require('bookmarks.storage').setup(opts) then
        return
    end

    require('bookmarks.decorations').setup(opts)
    local autocmds = require('bookmarks.autocmds')
    local navigation = require('bookmarks.navigation')
    autocmds.setup()



    if opts.default_mappings ~= false then
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
            navigation.jump_to_next(bookmarks)
        end, { desc = 'Jump to next bookmark in file' })

        vim.keymap.set('n', '<leader>bk', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bookmarks = autocmds.get_buffer_bookmarks(bufnr)
            navigation.jump_to_prev(bookmarks)
        end, { desc = 'Jump to prev bookmark in file' })

        vim.keymap.set('n', '<leader>bl',
            require('telescope').extensions.bookmarks.list,
            { desc = 'List bookmarks' }
        )
    elseif opts.mappings then
        -- Custom mappings setup
        if opts.mappings.add then
            vim.keymap.set('n', opts.mappings.add, function()
                local bufnr = require('bookmarks.commands').add_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Add bookmark' })
        end
        if opts.mappings.delete then
            vim.keymap.set('n', opts.mappings.delete, function()
                local bufnr = require('bookmarks.commands').remove_bookmark()
                require('bookmarks.autocmds').refresh_buffer(bufnr)
            end, { desc = 'Remove bookmark' })
        end
        if opts.mappings.list then
            vim.keymap.set('n', opts.mappings.list,
                require('telescope').extensions.bookmarks.list,
                { desc = 'List bookmarks' }
            )
        end
    end
end

return M

