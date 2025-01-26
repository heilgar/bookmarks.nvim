local M = {}
local config = nil

local db = nil

-- Default configuration
local default_config = {
    db_path = vim.fn.stdpath('data') .. '/bookmarks.db'
}

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

    return true
end

function M.setup(opts)
    -- Merge user config with defaults
    config = vim.tbl_deep_extend('force', default_config, opts or {})

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
            project_root = bookmark.project_root
        })
    end)

    if not success then
        vim.notify("Failed to add bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.remove_bookmark(filename, line, project_root)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return false
    end

    local success, err = pcall(function()
        db.bookmarks:remove({
            filename     = filename,
            line_nr      = line,
            project_root = project_root
        })
    end)

    if not success then
        vim.notify("Failed to remove bookmark: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.get_bookmarks(project_root)
    if not db or not db.bookmarks then
        vim.notify("Database not initialized", vim.log.levels.ERROR)
        return {}
    end

    local success, results = pcall(function()
        if project_root and project_root ~= "" then
            local query = string.format("SELECT * FROM bookmarks WHERE project_root = '%s'", project_root)
            return db:eval(query)
        else
            return db.bookmarks:get()
        end
    end)

    if not success then
        vim.notify("Failed to get bookmarks: " .. tostring(results), vim.log.levels.ERROR)
        return {}
    end

    local bookmarks = {}
    for _, row in ipairs(results) do
        table.insert(bookmarks, {
            filename     = row.filename,
            line         = row.line_nr,
            content      = row.content,
            timestamp    = row.timestamp,
            project_root = row.project_root
        })
    end

    return bookmarks
end

function M.get_file_bookmarks(filename, project_root)
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
        return db:eval(query)
    end)

    if not success or type(results) ~= "table" then
        vim.notify("Failed to get bookmarks for file: " .. vim.inspect(results), vim.log.levels.ERROR)
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
        })
    end

    return bookmarks
end

return M

