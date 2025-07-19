--- Storage and database operations for bookmarks.nvim.
-- Handles all SQLite interactions for bookmarks and lists.
-- @module bookmarks.storage
local M = {}
local config = nil

local db = nil

-- Default configuration
local default_config = {
    db_path = vim.fn.stdpath('data') .. '/bookmarks.db',
    debug = false
}

local function debug_print(...)
    if config and config.debug then
        print("[bookmarks.nvim]", ...)
    end
end

-- Utility: Check if a column exists in the bookmarks table
local function column_exists(db, column_name)
    local has_column = false
    local ok, result = pcall(function()
        local res = db:eval("PRAGMA table_info(bookmarks)")
        debug_print("PRAGMA table_info(bookmarks) result:", vim.inspect(res))
        if type(res) == "table" then
            for _, row in ipairs(res) do
                debug_print("Checking column:", row.name)
                if row.name == column_name then
                    has_column = true
                    break
                end
            end
        end
    end)
    debug_print("column_exists for", column_name, has_column)
    return has_column
end

-- Safe migration: Add columns if they do not exist
local function safe_migrate_bookmarks_table(db)
    debug_print("Running safe migration for bookmarks table")
    if not column_exists(db, "branch") then
        debug_print("Adding 'branch' column...")
        local ok, err = pcall(function()
            db:eval("ALTER TABLE bookmarks ADD COLUMN branch TEXT;")
        end)
        if not ok then
            debug_print("Error adding 'branch' column:", err)
        end
    else
        debug_print("'branch' column already exists")
    end
    if not column_exists(db, "list") then
        debug_print("Adding 'list' column...")
        local ok, err = pcall(function()
            db:eval("ALTER TABLE bookmarks ADD COLUMN list TEXT;")
        end)
        if not ok then
            debug_print("Error adding 'list' column:", err)
        end
    else
        debug_print("'list' column already exists")
    end
    -- Create bookmark_lists table if it doesn't exist (user lists only, no 'global')
    local ok, err = pcall(function()
        db:eval([[CREATE TABLE IF NOT EXISTS bookmark_lists (
            name TEXT PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
        )]])
    end)
    if not ok then
        debug_print("Error creating bookmark_lists table:", err)
    end
end

-- Initialize the database and create tables
local function init_database()
    if not config or not config.db_path then
        vim.notify("Invalid configuration", vim.log.levels.ERROR)
        return false
    end

    -- Debug prints
    -- print("Data directory:", vim.fn.stdpath('data'))
    -- print("Target DB path:", config.db_path)

    -- Ensure the directory exists
    local db_dir = vim.fn.fnamemodify(config.db_path, ':h')
    vim.fn.mkdir(db_dir, 'p')

    -- Try requiring sqlite
    local has_sqlite, sqlite = pcall(require, 'sqlite')
    if not has_sqlite then
        vim.notify("Failed to require sqlite: " .. tostring(sqlite), vim.log.levels.ERROR)
        return false
    end

    -- Use the "super-lazy constructor" approach
    local success, connection_or_err = pcall(function()
        return sqlite {
            -- The local DB file to use
            uri = config.db_path,

            -- Define a table named "bookmarks"
            bookmarks = {
                -- By setting "id = true", we get "INTEGER PRIMARY KEY"
                id           = true,

                -- The rest match your desired schema
                filename     = "text",    -- TEXT NOT NULL
                line_nr      = "integer", -- or "int"
                content      = "text",
                timestamp    = "integer",
                project_root = "text",

                -- "ensure=true" => CREATE TABLE IF NOT EXISTS
                ensure       = true,
            }
        }:open()
    end)

    if not success or not connection_or_err then
        vim.notify("Failed to create DB connection: " .. tostring(connection_or_err), vim.log.levels.ERROR)
        return false
    end

    db = connection_or_err

    -- Optionally create an index (super-lazy constructor doesn't auto‐create indexes)
    local success_idx, err_idx = pcall(function()
        db:eval([[
      CREATE INDEX IF NOT EXISTS idx_filename_line
      ON bookmarks(filename, line_nr)
    ]])
    end)

    if not success_idx then
        vim.notify("Failed to create index: " .. tostring(err_idx), vim.log.levels.ERROR)
        return false
    end

    -- Run safe migration for new columns
    safe_migrate_bookmarks_table(db)

    return true
end


--- Setup the storage module and initialize the database.
-- @param opts table: Storage configuration options.
-- @return boolean: True if successful, false otherwise.
function M.setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend('force', default_config, opts)
    -- Initialize database and create tables
    local success = init_database()
    if not success then
        vim.notify("Failed to initialize bookmarks database", vim.log.levels.ERROR)
        return false
    end
    return true
end

--- Add a new bookmark to the database.
-- @param bookmark table: Table with bookmark fields (filename, line, content, etc.)
-- @return boolean: True if successful, false otherwise.
function M.add_bookmark(bookmark)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return false
    end

    local success, err = pcall(function()
        db.bookmarks:insert({
            filename     = bookmark.filename,
            line_nr      = bookmark.line,
            content      = bookmark.content,
            timestamp    = bookmark.timestamp,
            project_root = bookmark.project_root,
            branch       = bookmark.branch,
            list         = bookmark.list,
        })
    end)

    if not success then
        vim.notify("Failed to add bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

--- Remove a bookmark from the database.
-- @param filename string: File name.
-- @param line number: Line number.
-- @param project_root string: Project root directory.
-- @param branch string|nil: Git branch name (if branch-specific).
-- @param list string|nil: Bookmark list name (or nil for global).
-- @return boolean: True if successful, false otherwise.
function M.remove_bookmark(filename, line, project_root, branch, list)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return false
    end

    local success, err = pcall(function()
        local conditions = {
            filename     = filename,
            line_nr      = line,
            project_root = project_root
        }
        if branch then
            conditions.branch = branch
        end
        if list == nil then
            conditions.list = nil
        else
            conditions.list = list
        end
        db.bookmarks:remove(conditions)
    end)

    if not success then
        vim.notify("Failed to remove bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

--- Get all bookmarks for a project, branch, and list.
-- @param project_root string: Project root directory.
-- @param branch string|nil: Git branch name (if branch-specific).
-- @param list string|nil: Bookmark list name (or nil for global).
-- @return table: List of bookmark tables.
function M.get_bookmarks(project_root, branch, list)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return {}
    end
    local success, results = pcall(function()
        local query = "SELECT * FROM bookmarks WHERE 1=1"
        if project_root and project_root ~= "" then
            query = query .. string.format(" AND project_root = '%s'", project_root)
        end
        if branch then
            query = query .. string.format(" AND branch = '%s'", branch)
        end
        -- Only filter by list if not 'all'
        if list == nil or list == "default" then
            query = query .. " AND list IS NULL"
        elseif list ~= "all" then
            query = query .. string.format(" AND list = '%s'", list)
        end
        -- If list == 'all', do not filter by list at all
        return db:eval(query)
    end)

    if not success then
        vim.notify("Failed to get bookmarks: " .. tostring(results), vim.log.levels.ERROR)
        return {}
    end

    if type(results) ~= "table" then
        return {}
    end

    local bookmarks = {}
    for _, row in ipairs(results) do
        table.insert(bookmarks, {
            filename     = row.filename,
            line         = row.line_nr,
            content      = row.content,
            timestamp    = row.timestamp,
            project_root = row.project_root,
            branch       = row.branch,
            list         = row.list,
        })
    end

    return bookmarks
end

--- Get all bookmarks for a specific file.
-- @param filename string: File name.
-- @param project_root string: Project root directory.
-- @param branch string|nil: Git branch name (if branch-specific).
-- @param list string|nil: Bookmark list name (or nil for global).
-- @return table: List of bookmark tables for the file.
function M.get_file_bookmarks(filename, project_root, branch, list)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return {}
    end

    local success, results = pcall(function()
        local query = string.format(
            "SELECT * FROM bookmarks WHERE filename = '%s' AND project_root = '%s'",
            filename,
            project_root
        )
        if branch then
            query = query .. string.format(" AND branch = '%s'", branch)
        end
        -- Only filter by list if not 'all'
        if list == nil or list == "default" then
            query = query .. " AND list IS NULL"
        elseif list ~= "all" then
            query = query .. string.format(" AND list = '%s'", list)
        end
        -- If list == 'all', do not filter by list at all
        return db:eval(query)
    end)

    if not success or type(results) ~= "table" then
        return {}
    end

    local bookmarks = {}
    for _, row in ipairs(results) do
        table.insert(bookmarks, {
            filename     = row.filename,
            line         = row.line_nr,
            content      = row.content,
            timestamp    = row.timestamp,
            project_root = row.project_root,
            branch       = row.branch,
            list         = row.list,
        })
    end

    return bookmarks
end

--- Check if a bookmark exists at a specific line in a file.
-- @param filename string: File name.
-- @param line number: Line number.
-- @param project_root string: Project root directory.
-- @param branch string|nil: Git branch name (if branch-specific).
-- @param list string|nil: Bookmark list name (or nil for global).
-- @return boolean: True if bookmark exists, false otherwise.
function M.bookmark_exists(filename, line, project_root, branch, list)
    if not db or not db.bookmarks then
        return false
    end

    local success, results = pcall(function()
        local query = string.format(
            "SELECT COUNT(*) as count FROM bookmarks WHERE filename = '%s' AND line_nr = %d AND project_root = '%s'",
            filename, line, project_root
        )
        if branch then
            query = query .. string.format(" AND branch = '%s'", branch)
        end
        -- Only filter by list if not 'all'
        if list == nil or list == "default" then
            query = query .. " AND list IS NULL"
        elseif list ~= "all" then
            query = query .. string.format(" AND list = '%s'", list)
        end
        -- If list == 'all', do not filter by list at all
        return db:eval(query)
    end)

    if not success or type(results) ~= "table" or #results == 0 then
        return false
    end

    return results[1].count > 0
end

-- List management functions
--- Create a new bookmark list.
-- @param name string: Name of the new list.
-- @return boolean: True if successful, false otherwise.
function M.create_list(name)
    if not db then return false end
    if not name or name == "default" then return false end
    local now = os.time()
    local ok, err = pcall(function()
        db:eval(string.format(
            "INSERT INTO bookmark_lists (name, created_at, updated_at) VALUES ('%s', %d, %d)",
            name, now, now
        ))
    end)
    if not ok then
        debug_print("Failed to create list:", err)
        return false
    end
    return true
end

--- Get all bookmark lists (including global).
-- @return table: List of bookmark list tables.
function M.get_lists()
    if not db then return {} end
    local ok, res = pcall(function()
        return db:eval("SELECT name, created_at, updated_at FROM bookmark_lists ORDER BY name ASC")
    end)
    local lists = {}
    if ok and type(res) == "table" then
        for _, row in ipairs(res) do
            table.insert(lists, row)
        end
    end
    -- Always include 'default' as the first list (not in DB)
    table.insert(lists, 1, { name = "default", created_at = nil, updated_at = nil })
    return lists
end

--- Rename a bookmark list.
-- @param old_name string: Old list name.
-- @param new_name string: New list name.
-- @return boolean: True if successful, false otherwise.
function M.rename_list(old_name, new_name)
    if not db then return false end
    if old_name == "default" or new_name == "default" then return false end
    local now = os.time()
    local ok, err = pcall(function()
        db:eval(string.format(
            "UPDATE bookmark_lists SET name = '%s', updated_at = %d WHERE name = '%s'",
            new_name, now, old_name
        ))
        db:eval(string.format(
            "UPDATE bookmarks SET list = '%s' WHERE list = '%s'",
            new_name, old_name
        ))
    end)
    if not ok then
        debug_print("Failed to rename list:", err)
        return false
    end
    return true
end

--- Delete a bookmark list.
-- @param name string: List name to delete.
-- @param opts table|nil: Options (e.g., reassign_to_global).
-- @return boolean: True if successful, false otherwise.
function M.delete_list(name, opts)
    if not db then return false end
    if name == "default" then return false end
    opts = opts or { reassign_to_default = true }
    local ok, err = pcall(function()
        db:eval(string.format("DELETE FROM bookmark_lists WHERE name = '%s'", name))
        if opts.reassign_to_default then
            db:eval(string.format("UPDATE bookmarks SET list = NULL WHERE list = '%s'", name))
        else
            db:eval(string.format("DELETE FROM bookmarks WHERE list = '%s'", name))
        end
    end)
    if not ok then
        debug_print("Failed to delete list:", err)
        return false
    end
    return true
end

return M

