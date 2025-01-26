local BookmarkList = {}
BookmarkList.__index = BookmarkList

function BookmarkList.new()
    return setmetatable({
        items = {} -- Initialize items array
    }, BookmarkList)
end

function BookmarkList:__len()
    return #self.items
end

function BookmarkList:is_empty()
    return #self.items == 0
end

-- Binary search helper
local function binary_search(items, line)
    local left, right = 1, #items

    while left <= right do
        local mid = math.floor((left + right) / 2)
        local mid_line = items[mid].line

        if mid_line == line then
            return mid, true
        elseif mid_line < line then
            left = mid + 1
        else
            right = mid - 1
        end
    end

    return left, false
end

function BookmarkList:insert_sorted(bookmark)
    if not bookmark or not bookmark.line then
        return
    end

    -- Find insertion point
    local pos = 1
    while pos <= #self.items and self.items[pos].line < bookmark.line do
        pos = pos + 1
    end

    -- Update if line exists, otherwise insert
    if pos <= #self.items and self.items[pos].line == bookmark.line then
        self.items[pos] = bookmark
    else
        table.insert(self.items, pos, bookmark)
    end
end

function BookmarkList:find_next(current_line)
    local pos, found = binary_search(self.items, current_line)

    if found and pos < #self.items then
        return self.items[pos + 1]
    end

    return self.items[pos]
end

function BookmarkList:find_prev(current_line)
    local pos, found = binary_search(self.items, current_line)

    if found and pos > 1 then
        return self.items[pos - 1]
    end

    return self.items[pos - 1]
end

function BookmarkList:remove(line)
    local pos, found = binary_search(self.items, line)
    if found then
        table.remove(self.items, pos)
        return true
    end
    return false
end

-- Iterator support
function BookmarkList:ipairs()
    return ipairs(self.items)
end

return BookmarkList

