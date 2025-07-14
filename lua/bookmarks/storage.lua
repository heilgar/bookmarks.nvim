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
        })
    end)

    if not success then
        vim.notify("Failed to add bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.remove_bookmark(filename, line, project_root, branch)
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
        db.bookmarks:remove(conditions)
    end)

    if not success then
        vim.notify("Failed to remove bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.get_bookmarks(project_root, branch)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return {}
    end

    local success, results = pcall(function()
        if project_root and project_root ~= "" then
            local query = string.format("SELECT * FROM bookmarks WHERE project_root = '%s'", project_root)
            if branch then
                query = query .. string.format(" AND branch = '%s'", branch)
            end
            return db:eval(query)
        else
            return db.bookmarks:get()
        end
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
        })
    end

    return bookmarks
end

function M.get_file_bookmarks(filename, project_root, branch)
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
        return db:eval(query)
    end)

    if not success or type(results) ~= "table" then
        -- vim.notify("Failed to get bookmarks for file: " .. vim.inspect(results), vim.log.levels.ERROR)
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
        })
    end

    return bookmarks
end

return M

