local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
end

local pickers      = require("telescope.pickers")
local finders      = require("telescope.finders")
local conf         = require("telescope.config").values
local actions      = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers   = require("telescope.previewers")

local storage      = require("bookmarks.storage")
local navigation   = require("bookmarks.navigation")
local autocmds     = require("bookmarks.autocmds")

local config = require('bookmarks').get_config()
local utils = require('bookmarks.utils')
local setup_opts = {
    pickers = {
      list = {},
      lists = {},
      status = {}
    }
}

--------------------------------------------------------------------------------
-- Load file for preview
--------------------------------------------------------------------------------
local function lazy_load_file(bufnr, winid, filename, line)
    -- Set a loading message
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "Loading file...",
        filename,
    })

    vim.schedule(function()
        local fd = vim.loop.fs_open(filename, "r", 438)
        if not fd then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
                "Error: Could not open file",
                filename,
            })
            return
        end

        local stat = vim.loop.fs_fstat(fd)
        if not stat then
            vim.loop.fs_close(fd)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
                "Error: Could not get file stats",
                filename,
            })
            return
        end

        vim.loop.fs_read(fd, stat.size, 0, function(err, data)
            vim.loop.fs_close(fd)

            vim.schedule(function()
                if err then
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
                        "Error reading file:",
                        filename,
                        err,
                    })
                    return
                end

                if not (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(winid)) then
                    return
                end

                local lines = vim.split(data, '\n', { plain = true })
                if lines[#lines] == '' then
                    table.remove(lines)
                end

                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                vim.api.nvim_win_set_cursor(winid, { line, 0 })

                local ft = vim.filetype.match({ filename = filename })
                if ft then
                    vim.bo[bufnr].filetype = ft
                end

                if vim.api.nvim_win_is_valid(winid) then
                    vim.api.nvim_set_option_value("number", true, { scope = "local", win = winid })
                    vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = winid })
                    vim.api.nvim_set_option_value("signcolumn", "yes", { scope = "local", win = winid })
                end

                -- Create highlight namespace for the bookmark line
                local ns_id = vim.api.nvim_create_namespace("bookmarks_preview_hl")

                -- Clear any existing highlights
                vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

                -- Add highlight to the bookmarked line (zero-based line number)
                local zero_based_line = line - 1
                if zero_based_line >= 0 and zero_based_line < #lines then
                    -- Check if BookmarkHighlight exists, otherwise create a fallback
                    local hl_exists = pcall(function()
                        return vim.api.nvim_get_hl(0, { name = "BookmarkHighlight" })
                    end)

                    if not hl_exists then
                        vim.api.nvim_set_hl(0, "BookmarkPreviewHL", {
                            bg = "#594d3e",
                            bold = true,
                            default = true,
                        })
                        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "BookmarkPreviewHL", zero_based_line, 0, -1)
                    else
                        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "BookmarkHighlight", zero_based_line, 0, -1)
                    end

                    -- Place the bookmark sign
                    -- First clear any existing signs
                    vim.fn.sign_unplace("bookmarks_preview_group", { buffer = bufnr })

                    -- Place the sign at the bookmarked line
                    -- Make sure BookmarkSign is defined, otherwise define it
                    local sign_defined = pcall(vim.fn.sign_getdefined, "BookmarkSign")
                    if not sign_defined or #vim.fn.sign_getdefined("BookmarkSign") == 0 then
                        -- Define bookmark sign highlight if it doesn't exist
                        local hl_sign_exists = pcall(function()
                            return vim.api.nvim_get_hl(0, { name = "BookmarkSignHighlight" })
                        end)

                        if not hl_sign_exists then
                            vim.api.nvim_set_hl(0, "BookmarkSignHighlight", {
                                fg = "#FFE5B4",
                                bold = true,
                                default = true,
                            })
                        end

                        vim.fn.sign_define("BookmarkSign", {
                            text = "",
                            texthl = "BookmarkSignHighlight",
                            linehl = "BookmarkHighlight",
                        })
                    end

                    vim.fn.sign_place(
                        0,
                        "bookmarks_preview_group",
                        "BookmarkSign",
                        bufnr,
                        {
                            lnum = line,
                            priority = 10
                        }
                    )
                end
            end)
        end)
    end)
end

--------------------------------------------------------------------------------
-- A custom previewer that opens the file at the bookmarked line on highlight.
--------------------------------------------------------------------------------
local function bookmark_previewer()
    return previewers.new_buffer_previewer({
        get_buffer_by_name = function(_, entry)
            return entry.value.filename
        end,
        define_preview = function(self, entry, state)
            -- print('Previeing file: ', entry.value.filename)
            local bmk = entry.value
            if not bmk or not bmk.filename then
                return
            end

            local filename = bmk.filename
            local line     = bmk.line or 1

            local bufnr    = self.state.bufnr
            local winid    = self.state.winid

            -- Clear the buffer explicitly before loading new content
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

            lazy_load_file(bufnr, winid, filename, line)
        end,
    })
end

--------------------------------------------------------------------------------
-- Format each bookmark entry for display
--------------------------------------------------------------------------------
local function format_bookmark(bookmark)
    local rel_path = vim.fn.fnamemodify(bookmark.filename, ":.")
    local time_str = os.date("%Y-%m-%d %H:%M", bookmark.timestamp or 0)
    local line_num = bookmark.line or 1
    local content = bookmark.content or ""

    -- Trim content if it's too long
    if #content > 60 then
        content = string.sub(content, 1, 57) .. "..."
    end

    -- Format with clear visual structure
    return string.format(
        "%d:%s │ %s │ %s",
        line_num,
        rel_path,
        content,
        time_str
    )
end


--------------------------------------------------------------------------------
-- The picker that displays bookmarks on the left and the file preview on the right
--------------------------------------------------------------------------------
local function list_bookmarks(opts)
    opts = vim.tbl_extend("force", setup_opts["pickers"]["list"], opts or {})

    local branch = nil
    local prompt_title = "📖 Bookmarks"
    if config.use_branch_specific then
        branch = utils.get_current_branch()
        if branch then
            prompt_title = prompt_title .. string.format(" (branch: %s)", branch)
        else
            prompt_title = prompt_title .. " (branch: unknown)"
        end
    end
    
    -- Add list information with visual indicators
    local active_list = config.active_list or 'default'
    if active_list == 'all' then
        prompt_title = prompt_title .. " [🔍 all lists]"
    elseif active_list == 'default' then
        prompt_title = prompt_title .. " [📋 default]"
    else
        prompt_title = prompt_title .. string.format(" [📁 %s]", active_list)
    end

    pickers.new(opts, {
        prompt_title        = prompt_title,
        finder              = finders.new_table({
            results = storage.get_bookmarks(vim.fn.getcwd(), branch, config.active_list),
            entry_maker = function(bookmark)
                local display = format_bookmark(bookmark)
                -- Add list indicator if not in default list
                if bookmark.list then
                    display = "[" .. bookmark.list .. "] " .. display
                end
                return {
                    value   = bookmark,
                    display = display,
                    ordinal = bookmark.filename .. (bookmark.content or ""),
                }
            end,
        }),
        sorter              = conf.generic_sorter(opts),
        previewer           = bookmark_previewer(),

        -- Key layout settings:
        layout_strategy     = "vertical",
        layout_config       = {
            height = 0.9,
            width = 0.9,
            preview_height = 0.6,
            prompt_position = "bottom",
        },

        always_show_preview = true,

        attach_mappings     = function(prompt_bufnr, map)
            -- When user presses <CR>, jump to the bookmark in the main window
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection and selection.value then
                    navigation.jump_to_bookmark(
                        selection.value.filename,
                        selection.value.line
                    )
                end
            end)


            -- Function to delete the currently selected bookmark
            local function delete_bookmark()
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                local selection = action_state.get_selected_entry()

                if selection and selection.value then
                    local bmk = selection.value
                    local config = init.get_config()
                    local branch = nil
                    if config.use_branch_specific then
                        branch = utils.get_current_branch()
                    end
                    -- Use the bookmark's actual list, not the active list
                    local list = bmk.list
                    storage.remove_bookmark(bmk.filename, bmk.line, bmk.project_root, branch, list)


                    -- Refresh buffer decorations
                    local bufnr = vim.fn.bufnr(bmk.filename)
                    if bufnr ~= -1 then
                        autocmds.refresh_buffer(bufnr)
                    end

                    -- Remove the entry from the picker's results
                    current_picker:delete_selection(function(entry)
                        -- Show notification after deletion
                        vim.notify('Bookmark deleted', vim.log.levels.INFO)
                    end)
                end
            end

            map('i', '<Del>', delete_bookmark)
            map('n', '<Del>', delete_bookmark)

            return true
        end,

    }):find()
end

--------------------------------------------------------------------------------
-- Picker for bookmark lists (switch, create, rename, delete)
--------------------------------------------------------------------------------
local function list_lists(opts)
    opts = vim.tbl_extend("force", setup_opts["pickers"]["lists"], opts or {})
    local init = require('bookmarks')
    local storage = require('bookmarks.storage')
    local commands = require('bookmarks.commands')
    local config = init.get_config()
    local lists = storage.get_lists()
    local active = config.active_list or 'default'
    -- Insert 'all' as a special entry at the top
    table.insert(lists, 1, { name = 'all' })
    pickers.new(opts, {
        prompt_title = '📁 Bookmark Lists',
        finder = finders.new_table({
            results = lists,
            entry_maker = function(list)
                local icon = "📁"
                if list.name == 'all' then
                    icon = "🔍"
                elseif list.name == 'default' then
                    icon = "📋"
                end
                
                local display = icon .. " " .. list.name
                if list.name == active then
                    display = "⭐ " .. display .. " (active)"
                end
                
                return {
                    value = list.name,
                    display = display,
                    ordinal = list.name,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            local function get_selection()
                local selection = action_state.get_selected_entry()
                return selection and selection.value
            end

            -- Switch to list on <CR>
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local name = get_selection()
                commands.switch_list(name)
            end)

            -- Create new list: <C-n>
            map('i', '<C-n>', function()
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'New list name: ' }, function(input)
                    if input and input ~= '' then
                        commands.create_list(input)
                    end
                end)
            end)
            map('n', '<C-n>', function()
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'New list name: ' }, function(input)
                    if input and input ~= '' then
                        commands.create_list(input)
                    end
                end)
            end)

            -- Rename list: <C-r>
            map('i', '<C-r>', function()
                local old = get_selection()
                if old == 'default' or old == 'all' then
                    vim.notify('Cannot rename default or all list', vim.log.levels.ERROR)
                    return
                end
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'Rename list to: ' }, function(new_name)
                    if new_name and new_name ~= '' then
                        commands.rename_list(old, new_name)
                    end
                end)
            end)
            map('n', '<C-r>', function()
                local old = get_selection()
                if old == 'default' or old == 'all' then
                    vim.notify('Cannot rename default or all list', vim.log.levels.ERROR)
                    return
                end
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'Rename list to: ' }, function(new_name)
                    if new_name and new_name ~= '' then
                        commands.rename_list(old, new_name)
                    end
                end)
            end)

            -- Delete list: <C-d>
            map('i', '<C-d>', function()
                local name = get_selection()
                if name == 'default' or name == 'all' then
                    vim.notify('Cannot delete default or all list', vim.log.levels.ERROR)
                    return
                end
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'Delete list ' .. name .. '? (y/n): ' }, function(input)
                    if input and input:lower() == 'y' then
                        commands.delete_list(name)
                    end
                end)
            end)
            map('n', '<C-d>', function()
                local name = get_selection()
                if name == 'default' or name == 'all' then
                    vim.notify('Cannot delete default or all list', vim.log.levels.ERROR)
                    return
                end
                actions.close(prompt_bufnr)
                vim.ui.input({ prompt = 'Delete list ' .. name .. '? (y/n): ' }, function(input)
                    if input and input:lower() == 'y' then
                        commands.delete_list(name)
                    end
                end)
            end)

            return true
        end,
        layout_strategy = 'vertical',
        layout_config = {
            height = 0.5,
            width = 0.4,
            prompt_position = 'top',
        },
    }):find()
end

--------------------------------------------------------------------------------
-- Picker for bookmark status information
--------------------------------------------------------------------------------
local function show_status(opts)
    opts = vim.tbl_extend("force", setup_opts["pickers"]["status"], opts or {})
    local init = require('bookmarks')
    local config = init.get_config()
    local utils = require('bookmarks.utils')
    
    local status_info = {
        { label = "Active List", value = config.active_list or 'default' },
        { label = "Branch Mode", value = config.use_branch_specific and "ON" or "OFF" },
    }
    
    if config.use_branch_specific then
        local branch = utils.get_current_branch()
        table.insert(status_info, { label = "Current Branch", value = branch or "unknown" })
    end
    
    pickers.new(opts, {
        prompt_title = '📊 Bookmark Status',
        finder = finders.new_table({
            results = status_info,
            entry_maker = function(item)
                return {
                    value = item,
                    display = "📋 " .. item.label .. ": " .. item.value,
                    ordinal = item.label,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        layout_strategy = 'vertical',
        layout_config = {
            height = 0.4,
            width = 0.6,
            prompt_position = 'top',
        },
    }):find()
end

--------------------------------------------------------------------------------
-- Register extension for Telescope
--------------------------------------------------------------------------------
return telescope.register_extension({
    setup = function(ext_config)
      setup_opts = vim.tbl_deep_extend("force", setup_opts, ext_config)
    end,
    exports = {
        bookmarks = list_bookmarks,
        list = list_bookmarks,
        lists = list_lists,
        status = show_status,
    },
})

