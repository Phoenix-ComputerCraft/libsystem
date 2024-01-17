--- The expect module provides error checking functions for other libraries.
--
-- @module system.expect

local expect = {}

local native_types = {["nil"] = true, boolean = true, number = true, string = true, table = true, ["function"] = true, userdata = true, thread = true}

local function funclike(v) return (type(v) == "table" and ((getmetatable(v) or {}).__call)) or type(v) == "function" end

local function check_type(msg, value, ...)
    local vt = type(value)
    local vmt
    if vt == "table" then
        local mt = getmetatable(value)
        if mt then vmt = mt.__name end
    end
    local args = table.pack(...)
    for _, typ in ipairs(args) do
        if native_types[typ] then if vt == typ then return value end
        elseif vmt == typ then return value
        elseif funclike(typ) and typ(value) then return value end
    end
    local info = debug.getinfo(2, "n")
    if info and info.name and info.name ~= "" then msg = msg .. " to '" .. info.name .. "'" end
    local types
    if #args == 1 and funclike(args[1]) then
        local _, err = args[1](value)
        error(msg .. " (" .. err .. ")", 3)
    else
        for i, v in ipairs(args) do args[i] = tostring(v) end
        if args.n == 1 then types = args[1]
        elseif args.n == 2 then types = args[1] .. " or " .. args[2]
        else types = table.concat(args, ", ", 1, args.n - 1) .. ", or " .. args[args.n] end
        error(msg .. " (expected " .. types .. ", got " .. vt .. ")", 3)
    end
end

--- Check that a numbered argument matches the expected type(s). If the type
-- doesn't match, throw an error.
-- This function supports custom types by checking the __name metaproperty.
-- Passing the result of @{expect.struct}, @{expect.array}, or @{expect.match}
-- as a type parameter will use that function as a validator.
-- @tparam number index The index of the argument to check
-- @tparam any value The value to check
-- @tparam string|function(v):boolean ... The types to check for
-- @treturn any `value`
function expect.expect(index, value, ...)
    return check_type("bad argument #" .. index, value, ...)
end

--- Check that a key in a table matches the expected type(s). If the type
-- doesn't match, throw an error.
-- This function supports custom types by checking the __name metaproperty.
-- Passing the result of @{expect.struct}, @{expect.array}, or @{expect.match}
-- as a type parameter will use that function as a validator.
-- @tparam any tbl The table (or other indexable value) to search through
-- @tparam any key The key of the table to check
-- @tparam string|function(v):boolean ... The types to check for
-- @treturn any The indexed value in the table
function expect.field(tbl, key, ...)
    local ok, str = pcall(string.format, "%q", key)
    if not ok then str = tostring(key) end
    return check_type("bad field " .. str, tbl[key], ...)
end

--- Check that a number is between the specified minimum and maximum values. If
-- the number is out of bounds, throw an error.
-- @tparam number num The number to check
-- @tparam[opt=-math.huge] number min The minimum value of the number (inclusive)
-- @tparam[opt=math.huge] number max The maximum value of the number (inclusive)
-- @treturn number `num`
function expect.range(num, min, max)
    expect.expect(1, num, "number")
    expect.expect(2, min, "number", "nil")
    expect.expect(3, max, "number", "nil")
    if max and min and max < min then error("bad argument #3 (min must be less than or equal to max)", 2) end
    if num ~= num or num < (min or -math.huge) or num > (max or math.huge) then error(("number outside of range (expected %s to be within %s and %s)"):format(num, min or -math.huge, max or math.huge), 3) end
    return num
end

local struct_mt = {
    __tostring = function() return "table" end,
    __call = function(self, tab)
        if type(tab) ~= "table" then return false, "field '' not a table" end
        for k, types in pairs(self.struct) do
            if type(types) == "string" or funclike(types) then types = {types} end
            local value = tab[k]
            local vt = type(value)
            local vmt
            if vt == "table" then
                local mt = getmetatable(value)
                if mt then vmt = mt.__name end
            end
            local ok = false
            for _, typ in ipairs(types) do
                if native_types[typ] then if vt == typ then ok = true break end
                elseif vmt == typ then ok = true break
                elseif funclike(typ) and typ(value) then ok = true break end
            end
            if not ok then
                if #types == 1 and funclike(types[1]) then
                    local _, err = types[1](value)
                    if err then
                        err = err:gsub("'([^']*)'", "'" .. k .. ".%1'")
                        return false, err
                    end
                end
                return false, "bad field '" .. k .. "'"
            end
        end
        return true
    end
}

--- Provides a special type that can check all of the fields of a table at once.
-- 
-- The `struct` parameter defines the structure of the table. This is a key-
-- value table, where the key is the name of the field and the value is the
-- expected type(s) of the field.
-- - If the value is a single string, the field must be that type.
-- - If the value is a list of strings, the field must be one of those types.
-- - Any type can be replaced by one of the special types as with @{expect.expect}.
--         
-- @tparam table struct The expected structure of the table
-- @treturn function(v):boolean A checker function, to be passed to @{expect.expect}
-- @usage Checks the structure of a complex table.
--     
--     expect(1, tbl, expect.struct {
--         name = "string",
--         age = "number",
--         phone = {expect.match "%d%d%d%-%d%d%d%-%d%d%d%d", "number"},
--         address = expect.struct {
--             address = "string",
--             state = "string",
--             zip = {"number", "nil"},
--             country = "string"
--         },
--         children = expect.array "string",
--         jobs = expect.array {"string", expect.struct {
--             title = "string",
--             employer = "string",
--             salary = {"number", "nil"}
--         }}
--     })
function expect.struct(struct)
    expect.expect(1, struct, "table")
    return setmetatable({struct = struct}, struct_mt)
end

local array_mt = {
    __tostring = function() return "table" end,
    __call = function(self, arr)
        if type(arr) ~= "table" then return false, "field '' not a table" end
        for i, value in ipairs(arr) do
            local vt = type(value)
            local vmt
            if vt == "table" then
                local mt = getmetatable(value)
                if mt then vmt = mt.__name end
            end
            local ok = false
            for _, typ in ipairs(self.types) do
                if native_types[typ] then if vt == typ then ok = true break end
                elseif vmt == typ then ok = true break
                elseif funclike(typ) and typ(value) then ok = true break end
            end
            if not ok then
                if #self.types == 1 and funclike(self.types[1]) then
                    local _, err = self.types[1](value)
                    if err then
                        err = err:gsub("'([^*]+)'", "'" .. i .. ".%1'")
                        return false, err
                    end
                end
                return false, "bad entry '" .. i .. "'"
            end
        end
        return true
    end
}

--- Provides a special type that can check for an array.
-- @tparam string|string[] types The type(s) to check for in each member
-- @treturn function(v):boolean A checker function, to be passed to @{expect.expect}
function expect.array(types)
    expect.expect(1, types, "string", "table")
    if type(types) == "string" or funclike(types) then types = {types} end
    return setmetatable({types = types}, array_mt)
end

local table_mt = {
    __tostring = function() return "table" end,
    __call = function(self, arr)
        if type(arr) ~= "table" then return false, "field '' not a table" end
        for k, value in pairs(arr) do
            local vt = type(value)
            local vmt
            if vt == "table" then
                local mt = getmetatable(value)
                if mt then vmt = mt.__name end
            end
            local ok = false
            for _, typ in ipairs(self.types) do
                if native_types[typ] then if vt == typ then ok = true break end
                elseif vmt == typ then ok = true break
                elseif funclike(typ) and typ(value) then ok = true break end
            end
            if not ok then
                if #self.types == 1 and funclike(self.types[1]) then
                    local _, err = self.types[1](value)
                    if err then
                        err = err:gsub("'([^']*)'", "'" .. k .. ".%1'")
                        return false, err
                    end
                end
                return false, "bad field '" .. k .. "'"
            end
        end
        return true
    end
}

--- Provides a special type that can check for a table with all entries.
-- @tparam string|string[] types The type(s) to check for in each member
-- @treturn function(v):boolean A checker function, to be passed to @{expect.expect}
function expect.table(types)
    expect.expect(1, types, "string", "table")
    if type(types) == "string" then types = {types} end
    return setmetatable({types = types}, table_mt)
end

local match_mt = {
    __tostring = function() return "string" end,
    __call = function(self, value)
        return type(value) == "string" and value:match(self.pattern) ~= nil, "pattern does not match"
    end
}

--- Provides a special type that can check for a string matching a pattern.
-- @tparam string pattern The pattern to check on the string
-- @treturn function(v):boolean A checker function, to be passed to @{expect.expect}
function expect.match(pattern)
    expect.expect(1, pattern, "string")
    return setmetatable({pattern = pattern}, match_mt)
end

return setmetatable(expect, {__call = function(_, ...) return expect.expect(...) end})