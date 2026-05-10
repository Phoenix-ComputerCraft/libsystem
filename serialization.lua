local expect = require "expect"

--- The serialization module provides functions for serializing and deserializing
--- objects in multiple formats, as well as some miscellaneous encoding types.
---
--- !doctype module
--- @class system.serialization
local serialization = {}

--- !doctype module
--- Base64 encoder/decoder
--- @class system.serialization.base64
serialization.base64 = {}

local b64str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Encodes a binary string into Base64.
--- @param str string The string to encode
--- @return string result The string's representation in Base64
function serialization.base64.encode(str)
    expect(1, str, "string")
    local retval = ""
    for s in str:gmatch "..." do
        local n = s:byte(1) * 65536 + s:byte(2) * 256 + s:byte(3)
        local a, b, c, d = bit32.extract(n, 18, 6), bit32.extract(n, 12, 6), bit32.extract(n, 6, 6), bit32.extract(n, 0, 6)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. b64str:sub(c+1, c+1) .. b64str:sub(d+1, d+1)
    end
    if #str % 3 == 1 then
        local n = str:byte(-1)
        local a, b = bit32.rshift(n, 2), bit32.lshift(bit32.band(n, 3), 4)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. "=="
    elseif #str % 3 == 2 then
        local n = str:byte(-2) * 256 + str:byte(-1)
        local a, b, c = bit32.extract(n, 10, 6), bit32.extract(n, 4, 6), bit32.lshift(bit32.extract(n, 0, 4), 2)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. b64str:sub(c+1, c+1) .. "="
    end
    return retval
end

--- Decodes a Base64 string to binary.
--- @param str string The Base64 to decode
--- @return string result The decoded data
function serialization.base64.decode(str)
    expect(1, str, "string")
    local retval = ""
    for s in str:gmatch "...." do
        if s:sub(3, 4) == '==' then
            retval = retval .. string.char(bit32.bor(bit32.lshift(b64str:find(s:sub(1, 1)) - 1, 2), bit32.rshift(b64str:find(s:sub(2, 2)) - 1, 4)))
        elseif s:sub(4, 4) == '=' then
            local n = (b64str:find(s:sub(1, 1))-1) * 4096 + (b64str:find(s:sub(2, 2))-1) * 64 + (b64str:find(s:sub(3, 3))-1)
            retval = retval .. string.char(bit32.extract(n, 10, 8)) .. string.char(bit32.extract(n, 2, 8))
        else
            local n = (b64str:find(s:sub(1, 1))-1) * 262144 + (b64str:find(s:sub(2, 2))-1) * 4096 + (b64str:find(s:sub(3, 3))-1) * 64 + (b64str:find(s:sub(4, 4))-1)
            retval = retval .. string.char(bit32.extract(n, 16, 8)) .. string.char(bit32.extract(n, 8, 8)) .. string.char(bit32.extract(n, 0, 8))
        end
    end
    return retval
end

--- JSON encoder/decoder
--- !doctype module
--- @class system.serialization.json
serialization.json = {}

---
--- json.lua
---
--- Copyright (c) 2020 rxi
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy of
--- this software and associated documentation files (the "Software"), to deal in
--- the Software without restriction, including without limitation the rights to
--- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
--- of the Software, and to permit persons to whom the Software is furnished to do
--- so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.
---

local function rotable(str)
    return setmetatable({}, {__newindex = function() error("attempt to modify read-only table") end, __tostring = function() return str end})
end

serialization.json.null = rotable "null"
serialization.json.emptyArray = rotable "[]"

--- ----------------------------------------------------------------------------
--- Encode
--- ----------------------------------------------------------------------------

local encode

local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
    return "null"
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    if val == serialization.json.null then return "null"
    elseif val == serialization.json.emptyArray then return "[]" end

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
            if type(k) ~= "number" then
                error("invalid table: mixed or invalid key types")
            end
            n = n + 1
        end
        if n ~= #val then
            error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"

    else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end


local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


--- Serializes an arbitrary Lua object into a JSON string.
--- @param val any The value to encode
--- @return string result The JSON representation of the object
function serialization.json.encode(val)
    return ( encode(val) )
end


--- ----------------------------------------------------------------------------
--- Decode
--- ----------------------------------------------------------------------------

local parse

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                                             f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s, opts)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
     -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    elseif n1 < 256 and opts and opts.binary_escapes then
        return string.char(n1)
    else
        return codepoint_to_utf8(n1)
    end
end


local function parse_string(str, i, opts)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
        local x = str:byte(j)

        if x < 32 then
            decode_error(str, j, "control character in string")

        elseif x == 92 then -- `\`: Escape
            res = res .. str:sub(k, j - 1)
            j = j + 1
            local c = str:sub(j, j)
            if c == "u" then
                local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                                 or str:match("^%x%x%x%x", j + 1)
                                 or decode_error(str, j - 1, "invalid unicode escape in string")
                res = res .. parse_unicode_escape(hex, opts)
                j = j + #hex
            else
                if not escape_chars[c] then
                    decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                end
                res = res .. escape_char_map_inv[c]
            end
            k = j + 1

        elseif x == 34 then -- `"`: End of string
            res = res .. str:sub(k, j - 1)
            return res, j + 1
        end

        j = j + 1
    end

    decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end


local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end


local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
        local x
        i = next_char(str, i, space_chars, true)
        -- Empty / end of array?
        if str:sub(i, i) == "]" then
            i = i + 1
            break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end


local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
        local key, val
        i = next_char(str, i, space_chars, true)
        -- Empty / end of object?
        if str:sub(i, i) == "}" then
            i = i + 1
            break
        end
        -- Read key
        if str:sub(i, i) ~= '"' then
            decode_error(str, i, "expected string for key")
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
            decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        -- Read value
        val, i = parse(str, i)
        -- Set
        res[key] = val
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end


local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
}


parse = function(str, idx, opts)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx, opts)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


--- Parses a JSON string and returns a Lua value represented by the string.
--- @param str string The JSON string to decode
--- @param opts? {binary_escapes:boolean|nil} Any options to pass
--- @return any result The Lua value from the JSON
function serialization.json.decode(str, opts)
    expect(1, str, "string")
    local res, idx = parse(str, next_char(str, 1, space_chars, true), opts)
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

--- Saves a Lua value to a JSON file.
--- @param val any The value to save
--- @param path string The path to the file to save
function serialization.json.save(val, path)
    expect(2, path, "string")
    local file = assert(io.open(path, "w"))
    file:write(serialization.json.encode(val))
    file:close()
end

--- Loads a JSON file into a Lua value.
--- @param path string The path to the file to load
--- @return any result The loaded value
function serialization.json.load(path)
    expect(1, path, "string")
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    return serialization.json.decode(data)
end

--- Lua table encoder/decoder
--- !doctype module
--- @class system.serialization.lua
serialization.lua = {}

local keywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["goto"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

local function lua_serialize(val, stack, opts, level)
    if stack[val] then error("Cannot serialize recursive value", 0) end
    local tt = type(val)
    if tt == "table" then
        if not next(val) then return "{}" end
        stack[val] = true
        local res = opts.minified and "{" or "{\n"
        local num = {}
        for i, v in ipairs(val) do
            if not opts.minified then res = res .. ("    "):rep(level) end
            num[i] = true
            res = res .. lua_serialize(v, stack, opts, level + 1) .. (opts.minified and "," or ",\n")
        end
        for k, v in pairs(val) do if not num[k] then
            if not opts.minified then res = res .. ("    "):rep(level) end
            if type(k) == "string" and k:match "^[A-Za-z_][A-Za-z0-9_]*$" and not keywords[k] then res = res .. k
            else res = res .. "[" .. lua_serialize(k, stack, opts, level + 1) .. "]" end
            res = res .. (opts.minified and "=" or " = ") .. lua_serialize(v, stack, opts, level + 1) .. (opts.minified and "," or ",\n")
        end end
        if opts.minified then res = res:gsub(",$", "")
        else res = res .. ("    "):rep(level - 1) end
        stack[val] = nil
        return res .. "}"
    elseif tt == "function" and opts.allow_functions then
        local ok, dump = pcall(string.dump, val)
        if not ok then error("Cannot serialize C function", 0) end
        dump = ("%q"):format(dump):gsub("\\[%z\1-\31\127-\255]", function(c) return ("\\%03d"):format(string.byte(c)) end)
        local ups = {n = 0}
        stack[val] = true
        for i = 1, math.huge do
            local ok, name, value = pcall(debug.getupvalue, val, i)
            if not ok or not name then break end
            ups[i] = value
            ups.n = i
        end
        local name = "=(serialized function)"
        local ok, info = pcall(debug.getinfo, val, "S")
        if ok then name = info.source or name end
        local v = ("__function(%s,%q,%s)"):format(dump, name, lua_serialize(ups, stack, opts, level + 1))
        stack[val] = nil
        return v
    elseif tt == "nil" or tt == "number" or tt == "boolean" or tt == "string" then
        return ("%q"):format(val):gsub("\\\n", "\\n"):gsub("\\?[%z\1-\31\127-\255]", function(c) return ("\\%03d"):format(string.byte(c)) end)
    else
        error("Cannot serialize type " .. tt, 0)
    end
end

--- Serializes an arbitrary Lua object into a serialized Lua string.
--- @param val any The value to encode
--- @param opts? {minified:boolean,allow_functions:boolean} Any options to specify while encoding
--- @return string result The serialized Lua representation of the object
function serialization.lua.encode(val, opts)
    expect(2, opts, "table", "nil")
    return lua_serialize(val, {}, opts or {}, 1)
end

--- Parses a serialized Lua string and returns a Lua value represented by the string.
--- @param str string The serialized Lua string to decode
--- @param opts? {allow_functions:boolean} Any options to specify while decoding
--- @return any result The Lua value from the serialized Lua
function serialization.lua.decode(str, opts)
    opts = expect(2, opts, "table", "nil") or {}
    local env = {}
    local fns = {}
    if opts.allow_functions then function env.__function(code, name, ups)
        expect(1, code, "string")
        expect(3, ups, "table")
        expect.field(ups, "n", "number")
        local fn = assert(load(code, name, "b", {}))
        for i = 1, ups.n do debug.setupvalue(fn, i, ups[i]) end
        fns[#fns+1] = fn
        return fn
    end end
    local res = assert(load("return " .. str, "=unserialize", "t", env))()
    for _, v in ipairs(fns) do setfenv(v, _G) end
    return res
end

--- Saves a Lua value to a serialized Lua file.
--- @param val any The value to save
--- @param path string The path to the file to save
--- @param opts? {minified:boolean,allow_functions:boolean} Any options to specify while encoding
function serialization.lua.save(val, path, opts)
    expect(2, path, "string")
    local file = assert(io.open(path, "w"))
    file:write(serialization.lua.encode(val, opts))
    file:close()
end

--- Loads a serialized Lua file into a Lua value.
--- @param path string The path to the file to load
--- @param opts? {allow_functions:boolean} Any options to specify while decoding
--- @return any result The loaded value
function serialization.lua.load(path, opts)
    expect(1, path, "string")
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    return serialization.lua.decode(data, opts)
end

--- TOML configuration encoder/decoder
--- !doctype module
--- @class system.serialization.toml
serialization.toml = {}

local function encodeTOMLArray(arr, opts, names)
    local int, str = false, false
    for l in pairs(arr) do
        if type(l) == "number" then int = true
        elseif type(l) == "string" then str = true
        else error("key " .. table.concat(names, ".") .. "." .. tostring(l) .. " is not a string") end
    end
    local e = #names + 1
    if not int and not str then return "[]"
    elseif int and str then error("invalid entry " .. table.concat(names, ".") .. " (contains both array and dictionary values)")
    elseif int then
        local retval = "["
        for i, v in ipairs(arr) do
            if type(v) == "table" then
                names[e] = tostring(i)
                retval = retval .. (retval == "[" and "" or ", ") .. encodeTOMLArray(v, opts, names)
                names[e] = nil
            else retval = retval .. (retval == "[" and "" or ", ") .. lua_serialize(v, {}, {}, #names) end
        end
        return retval .. "]"
    else
        local res = "{"
        for k, v in pairs(arr) do
            if res ~= "{" then res = res .. ", " end
            if type(k) == "string" and k:match "^[A-Za-z0-9_%-]+$" then res = res .. k
            else res = res .. lua_serialize(k, {}, {}, #names) end
            if type(v) == "table" then
                names[e] = k
                res = res .. " = " .. encodeTOMLArray(v, opts, names)
                names[e] = nil
            else res = res .. " = " .. lua_serialize(v, {}, {}, #names) end
        end
        return res .. "}"
    end
end

local function encodeTOML(tbl, opts, names)
    local retval = ""
    local indent = opts.indent == false and "" or ("    "):rep(#names)
    if #names > 0 then retval = ("%s[%s]\n"):format(("    "):rep(#names - 1), table.concat(names, ".")) end
    local tbls, arrs = {}, {}
    local e = #names + 1
    for k, v in pairs(tbl) do
        assert(type(k) == "string", "key " .. table.concat(names, ".") .. "." .. tostring(k) .. " is not a string")
        local key = k:match("^[A-Za-z0-9_%-]+$") and k or lua_serialize(k, {}, {}, 1)
        local t = type(v)
        if t == "table" then
            local int, str, tab = false, false, true
            for l, w in pairs(v) do
                if type(l) == "number" then int = true
                elseif type(l) == "string" then str = true
                else error("key " .. table.concat(names, ".") .. "." .. tostring(k) .. "." .. tostring(l) .. " is not a string") end
                if type(w) ~= "table" then tab = false
                else for m in pairs(w) do if type(m) ~= "string" then tab = false break end end end
            end
            if not int and not str then retval = retval .. indent .. key .. " = []\n"
            elseif int and str then error("invalid entry " .. table.concat(names, ".") .. "." .. tostring(k) .. " (contains both array and dictionary values)")
            elseif int then
                if tab then
                    arrs[k] = v
                else
                    names[e] = k
                    retval = retval .. indent .. key .. " = " .. encodeTOMLArray(v, opts, names)
                    names[e] = nil
                end
            else tbls[k] = v end
        else retval = retval .. indent .. key .. " = " .. lua_serialize(v, {}, {}, #names) .. "\n" end
    end
    for k, arr in pairs(arrs) do
        names[e] = k
        for _, v in ipairs(arr) do
            retval = retval .. ("%s[[%s]]\n"):format(indent, table.concat(names, ".")) .. encodeTOML(v, opts, names) .. "\n"
        end
    end
    for k, v in pairs(tbls) do
        names[e] = k
        retval = retval .. ("%s[%s]\n"):format(indent, table.concat(names, ".")) .. encodeTOML(v, opts, names) .. "\n"
    end
    names[e] = nil
    return retval
end

--- Encodes a table into TOML format. This table must only have integer or
--- string keys in itself and each subtable, and cannot mix strings and ints.
--- @param tbl table The table to encode
--- @param opts? {indent:boolean} Any options to specify while encoding
--- @return string result The encoded TOML data
function serialization.toml.encode(tbl, opts)
    expect(1, tbl, "table")
    expect(2, opts, "table", "nil")
    return encodeTOML(tbl, opts or {}, {})
end

local function traverse(tab, name, pos, ln, wantlast, opts)
    local last, nm
    while pos < #name do
        if pos > 1 then
            pos = name:match("^%s*()", pos)
            if wantlast and name:sub(pos, pos) == "=" then return last, nm, pos + 1 end
            if name:sub(pos, pos) ~= "." then error("Expected . on line " .. ln, 3) end
            pos = name:match("^%s*()", pos + 1)
        end
        local key
        if name:match('^"', pos) then key, pos = parse_string(name, pos + 1, opts)
        elseif name:match("^'", pos) then key, pos = name:match("'([^']*)'()", pos)
        else key, pos = name:match("^([A-Za-z0-9_%-]+)()", pos) end
        if not key then error("Invalid key name on line " .. ln, 3) end
        last, nm = tab, key
        if not tab[key] then tab[key] = {} end
        tab = tab[key]
    end
    if wantlast then error("Expected = on line " .. ln, 3) end
    return tab
end

local function next_token(line, pos, ln)
    pos = line:match("^%s*()", pos)
    while pos > #line or line:sub(pos, pos) == "#" do
        line = coroutine.yield()
        ln = ln + 1
        pos = line:match "^%s*()"
    end
    return line, pos, ln
end

local function toml_assign(tab, key, line, pos, ln, opts)
    local op = line:sub(pos, pos)
    while op == "#" do
        line = coroutine.yield()
        ln = ln + 1
        pos = line:match "^%s*()"
        op = line:sub(pos, pos)
    end
    if op == "[" then
        local retval = {}
        local i = 1
        line, pos, ln = next_token(line, pos + 1, ln)
        while true do
            op = line:sub(pos, pos)
            if op == "]" then break end
            line, pos, ln = toml_assign(retval, i, line, pos, ln, opts)
            line, pos, ln = next_token(line, pos, ln)
            op = line:sub(pos, pos)
            if op == "]" then break end
            if op ~= "," then error("Expected , on line " .. ln, 0) end
            line, pos, ln = next_token(line, pos + 1, ln)
            i = i + 1
        end
        tab[key] = retval
        return line, pos + 1, ln
    elseif op == "{" then
        local retval = {}
        line, pos, ln = next_token(line, pos + 1, ln)
        while true do
            op = line:sub(pos, pos)
            if op == "}" then break end
            local t, k
            t, k, pos = traverse(retval, line, pos, ln, true, opts)
            line, pos, ln = next_token(line, pos, ln)
            line, pos, ln = toml_assign(t, k, line, pos, ln, opts)
            line, pos, ln = next_token(line, pos, ln)
            op = line:sub(pos, pos)
            if op == "}" then break end
            if op ~= "," then error("Expected , on line " .. ln, 0) end
            line, pos, ln = next_token(line, pos + 1, ln)
        end
        tab[key] = retval
        return line, pos + 1, ln
    elseif op == "'" then
        if line:match("^'''", pos) then
            pos = pos + 3
            local str = ""
            while not line:find("'''", pos) do
                if not (str == "" and pos == #line) then
                    str = str .. line:sub(pos) .. "\n"
                end
                line = coroutine.yield()
                ln, pos = ln + 1, 1
            end
            str = str .. line:sub(pos, line:find("'''", pos) - 1)
            pos = line:match("'''()", pos)
            tab[key] = str
            return line, pos, ln
        else
            local str, pos = line:match("^'([^']*)'()", pos)
            if not str then error("Invalid literal string on line " .. ln, 0) end
            tab[key] = str
            return line, pos, ln
        end
    elseif op == '"' then
        if line:match('^"""', pos) then
            local s = ""
            while not line:find('"""', pos) do
                if not (s == "" and pos == #line) then
                    s = s .. line:sub(pos) .. "\n"
                end
                line = coroutine.yield()
                ln, pos = ln + 1, 1
            end
            s = s .. line:sub(pos, line:find('"""', pos) - 1)
            s = s:gsub("\\\r?\n", ""):gsub('"', '\\"') .. '"'
            tab[key] = parse_string(s, 1, opts)
            pos = line:match('"""()', pos)
            return line, pos, ln
        else
            local str, pos = parse_string(line, pos, opts)
            if not str then error("Invalid string on line " .. ln, 0) end
            tab[key] = str
            return line, pos, ln
        end
    elseif line:match("^%d%d%d%d%-%d%d%-%d%d[T ]%d%d:%d%d:%d%d", pos) then
        local y, M, d, h, m, s, pos = line:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)()", pos)
        local date = {
            year = tonumber(y),
            month = tonumber(M),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(m),
            sec = tonumber(s)
        }
        local time = os.time(date)
        if line:match("^%.%d+", pos) then
            local ss
            ss, pos = line:match("(%.%d+)()", pos)
            time = time + tonumber("0" .. ss)
        end
        local c = line:sub(pos, pos)
        if c == "+" or c == "-" then
            local oh, om
            oh, om, pos = line:match("^[%+%-](%d%d):(%d%d)()", pos)
            if not oh then error("Invalid date format on line " .. ln, 0) end
            local offset = tonumber(oh) * 3600 + tonumber(om) * 60
            if c == "-" then offset = -offset end
            time = time + offset
        elseif c == "Z" then pos = pos + 1 end
        tab[key] = time
        return line, pos, ln
    elseif line:match("^%d%d%d%d%-%d%d%-%d%d", pos) then
        local y, M, d, pos = line:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)()", pos)
        local date = {
            year = tonumber(y),
            month = tonumber(M),
            day = tonumber(d),
            hour = 0,
            min = 0,
            sec = 0
        }
        local time = os.time(date)
        tab[key] = time
        return line, pos, ln
    elseif line:match("^%d%d%:%d%d:%d%d", pos) then
        local h, m, s, pos = line:match("^(%d%d):(%d%d):(%d%d)()", pos)
        local time = h * 3600 + m * 60 * s
        if line:match("^%.%d+", pos) then
            local ss
            ss, pos = line:match("(%.%d+)()", pos)
            time = time + tonumber("0" .. ss)
        end
        tab[key] = time
        return line, pos, ln
    elseif op:match "%d" or op == "+" or op == "-" then
        if line:match("^%+inf", pos) then tab[key] = math.huge return line, pos + 4, ln
        elseif line:match("^%-inf", pos) then tab[key] = -math.huge return line, pos + 4, ln
        elseif line:match("^%+nan", pos) then tab[key] = -(0/0) return line, pos + 4, ln
        elseif line:match("^%-nan", pos) then tab[key] = 0/0 return line, pos + 4, ln
        elseif line:match("^[%+%-]?0o", pos) then
            local sign, num, pos = line:match("^([%+%-]?)0o([0-7_]+)()", pos):gsub("_", "")
            if not num then error("Invalid number on line " .. ln, 0) end
            num = tonumber(num, 8)
            if not num then error("Invalid number on line " .. ln, 0) end
            if sign == "-" then num = -num end
            tab[key] = num
            return line, pos, ln
        elseif line:match ("^[%+%-]?0b", pos) then
            local sign, num, pos = line:match("^([%+%-]?)0b([01_]+)()", pos):gsub("_", "")
            if not num then error("Invalid number on line " .. ln, 0) end
            num = tonumber(num, 2)
            if not num then error("Invalid number on line " .. ln, 0) end
            if sign == "-" then num = -num end
            tab[key] = num
            return line, pos, ln
        else
            local num, pos = line:match("^([%+%-]?[%d_]+%.?[%d_]*[Ee]?[%+%-]?[%d_]*)()", pos)
            num = num:gsub("_", "")
            num = tonumber(num)
            if not num then error("Invalid number on line " .. ln, 0) end
            tab[key] = num
            return line, pos, ln
        end
    elseif line:match("^true", pos) then tab[key] = true return line, pos + 4, ln
    elseif line:match("^false", pos) then tab[key] = false return line, pos + 5, ln
    elseif line:match("^nil", pos) then tab[key] = nil return line, pos + 3, ln -- extension
    elseif line:match("^inf", pos) then tab[key] = math.huge return line, pos + 3, ln
    elseif line:match("^nan", pos) then tab[key] = -(0/0) return line, pos + 3, ln
    else error("Unexpected " .. op .. " on line " .. ln, 0) end
end

--- Parses TOML data into a table.
--- @param str string The TOML data to decode
--- @param opts? {binary_escapes:boolean|nil} Options for decoding
--- @return table result A table representing the TOML data
function serialization.toml.decode(str, opts)
    expect(1, str, "string")
    opts = expect(2, opts, "table", "nil") or {}
    local retval = {}
    local current = retval
    local ln = 1
    local coro
    for line in str:gmatch "([^\r\n]*)\r?\n?" do
        if coro then
            -- continuation of multi-line value
            local ok, err = coro:resume(line)
            if not ok then error(err, 3) end
            if coro:status() == "dead" then coro = nil end
        else
            line = line:gsub("^%s+", "")
            if line:match "^#" or line == "" then -- nothing
            elseif line:match "^%[%[" then
                local tag = line:match "^%[(%b[])%]"
                if not tag then error("Expected ]] on line " .. ln, 2) end
                current = traverse(retval, tag:sub(2, -2), 1, ln, nil, opts)
                current[#current+1] = {}
                current = current[#current]
            elseif line:match "^%[" then
                local tag = line:match "^%b[]"
                if not tag then error("Expected ] on line " .. ln, 2) end
                current = traverse(retval, tag:sub(2, -2), 1, ln, nil, opts)
            else
                local last, key, pos = traverse(current, line, 1, ln, true, opts)
                pos = line:match("^%s*()", pos)
                if not pos then error("Expected value on line " .. ln, 2) end
                coro = coroutine.create(toml_assign)
                local ok, err = coro:resume(last, key, line, pos, ln, opts)
                if not ok then error(err, 3) end
                if coro:status() == "dead" then coro = nil end
            end
        end
        ln = ln + 1
    end
    if coro then error("Unfinished value at end of file", 2) end
    return retval
end

--- Saves a table to a TOML file.
--- @param val table The value to save
--- @param path string The path to the file to save
--- @param opts? {indent:boolean} Any options to specify while encoding
function serialization.toml.save(val, path, opts)
    expect(1, val, "table")
    expect(2, path, "string")
    expect(3, opts, "table", "nil")
    local file = assert(io.open(path, "w"))
    file:write(serialization.toml.encode(val, opts))
    file:close()
end

--- Loads a TOML file into a table.
--- @param path string The path to the file to load
--- @param opts? table Options (none available in this version)
--- @return table result The loaded value
function serialization.toml.load(path, opts)
    expect(1, path, "string")
    expect(2, opts, "table", "nil")
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    return serialization.toml.decode(data, opts)
end

--- MIT License
---
--- Copyright (c) 2023-2025 JackMacWindows
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the "Software"), to deal
--- in the Software without restriction, including without limitation the rights
--- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--- copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.

--- ===== Notes =====
--- * Includes the following types:
---  - All standard C89 integral & float types
---  - C++ bool
---  - C stdint.h fixed-width integer types
---  - size_t
---  - Lua number types (lua_Integer, lua_Unsigned, lua_Number)
---  - Special string types: string_t = variable width string preceeded by size_t for length,
---    string[8|16|32|64]_t = string with fixed-width integer size
---  - [const] char * = NUL-terminated C string
---  - [const] char[] = fixed width string
--- * Pointers are not supported outside C strings
--- * Variable-length arrays and strings are supported, with either an explicit
---  size field named in the brackets, or an automatic size_t prefix if empty
--- * Fields used as sizes for variable-length arrays/strings can be implicitly
---  calculated when encoding if not present in the source table
--- * The decoder accepts an index to start decoding at as the second argument
--- * The decoder only parses the fields for the struct, and returns the index of
---  the next data (like string.unpack)
--- * To encode a union, pass a table with *exactly one* member
--- * All fields encoded must have a value, including filling all array entries
--- * Do not include default values in structure definitions
--- * The length operator on a type returns the size of the type (provided it
---  doesn't have char* or string_t strings, or VLAs)
--- * Enumerations can be used to shorten strings to numbers in the data - simply
---  define an enum with the strings expected, and they'll be turned into ints
---  in the stored data

--[=[ Usage:
    local struct = require "struct"

    -- define struct type
    local myStruct = struct [[
        typedef uint32_t array8_t[8];
        struct {
            int foo;
            double bar;
            array8_t baz;
            const char * name;
            union {
                int i;
                float f;
            } data;
        }
    ]]
    -- encode table to binary
    local binary = myStruct {
        foo = 10,
        bar = 3.14,
        baz = {1, 2, 3, 4, 5, 6, 7, 8},
        name = "Hello World!",
        data = {f = 0.5}
    }
    -- decode to table
    local tab = myStruct(binary)
    print(tab.name, tab.data.i)

    -- chain type definitions
    local types = {}
    struct([[
        typedef struct {
            unsigned short	coord, inc;
        } EnvNode;

        typedef struct {
            EnvNode			nodes[12];
            unsigned char	max;
            unsigned char	sus;
            unsigned char	loopStart;
            unsigned char	flags;
        } Envelope;

        typedef struct {
            unsigned short	samples[96];
            Envelope		envVol;
            Envelope		envPan;
            unsigned short	volFade;
            unsigned char	vibType;
            unsigned char	vibSweep;
            unsigned char	vibDepth;
            unsigned char	vibRate;
        } Instrument;
    ]], types)
    -- get the size of a type
    print(#types.Instrument)
    -- create empty object
    local inst = types.Instrument()
    inst.envVol.nodes[1] = {5, 12}
    -- write to file
    local file = io.open("file.bin", "wb")
    file:write(types.Instrument(inst))
    file:close()

    -- variable length arrays
    struct([[
        typedef struct {
            uint8_t szNodes;
            EnvNode nodes[szNodes];
        } VarEnvelope;
    ]], types)
    local st = {szNodes = 6, nodes = {}}
    for i = 1, 6 do st.nodes[i] = {coord = i*2-1, inc = i*2} end
    -- encode
    local data = types.VarEnvelope(st)
    -- decode
    local tab = types.VarEnvelope(data)
    print(tab.nodes[6].coord)
--]=]

local keywords = {
    bool = {0},
    char = {1},
    short = {2},
    long = {3},
    int = {4},
    float = {5},
    double = {6},
    unsigned = {7},
    signed = {8},
    const = {9},
    typedef = {10},
    struct = {11},
    union = {12},
    enum = {13},
}

local symbols = {
    ['*'] = {16},
    ['['] = {17},
    [']'] = {18},
    ['{'] = {19},
    ['}'] = {20},
    [';'] = {21},
    [','] = {22},
    ['='] = {23},
}

for k, v in pairs(keywords) do setmetatable(v, {__tostring = function() return k end}) end
for k, v in pairs(symbols) do setmetatable(v, {__tostring = function() return k end}) end

local function mktype(a, ...) return a and 2^a[1] + mktype(...) or 0 end

local base_types = {
    [mktype(keywords.bool)] = setmetatable({}, {__call = function(_, v, p)
        if type(v) == "string" then return v:byte(p) ~= 0, (p or 1) + 1
        elseif type(v) == "boolean" then return v and "\x01" or "\0" end
    end, __len = function() return 1 end}),
    [mktype(keywords.char)] = "b",
    [mktype(keywords.signed, keywords.char)] = "b",
    [mktype(keywords.unsigned, keywords.char)] = "B",
    [mktype(keywords.short)] = "h",
    [mktype(keywords.signed, keywords.short)] = "h",
    [mktype(keywords.unsigned, keywords.short)] = "H",
    [mktype(keywords.int)] = "i",
    [mktype(keywords.signed, keywords.int)] = "i",
    [mktype(keywords.signed)] = "i",
    [mktype(keywords.unsigned, keywords.int)] = "I",
    [mktype(keywords.unsigned)] = "I",
    [mktype(keywords.long, keywords.int)] = "l",
    [mktype(keywords.long, keywords.signed, keywords.int)] = "l",
    [mktype(keywords.long, keywords.signed)] = "l",
    [mktype(keywords.long, keywords.unsigned, keywords.int)] = "L",
    [mktype(keywords.long, keywords.unsigned)] = "L",
    [mktype(keywords.float)] = "f",
    [mktype(keywords.double)] = "d",
    int8_t = "i1",
    uint8_t = "I1",
    int16_t = "i2",
    uint16_t = "I2",
    int32_t = "i4",
    uint32_t = "I4",
    int64_t = "i8",
    uint64_t = "I8",
    intmax_t = "i8",
    uintmax_t = "I8",
    size_t = "T",
    string_t = "s",
    string8_t = "s1",
    string16_t = "s2",
    string32_t = "s4",
    string64_t = "s8",
    lua_Integer = "j",
    lua_Unsigned = "J",
    lua_Number = "n",
}

local struct, union

local array_mt = {
    __call = function(self, obj, pos, partial_struct)
        local size = self.size
        if type(obj) == "table" then
            local res = ""
            if size then
                if type(size) == "string" then
                    if not partial_struct then error("missing outer structure for size field '" .. size .. "'") end
                    size = partial_struct[size]
                    if size == nil then size = #obj end
                    if type(size) ~= "number" then error("size field '" .. self.size .. "' for array is not a number") end
                end
                if type(self.type) == "string" then
                    res = self.type:rep(size):pack(table.unpack(obj, 1, size))
                else
                    for i = 1, size do
                        res = res .. self.type(obj[i])
                    end
                end
            else
                res = ("T"):pack(#obj)
                if type(self.type) == "string" then
                    res = res .. self.type:rep(#obj):pack(table.unpack(obj, 1, #obj))
                else
                    for i = 1, #obj do
                        res = res .. self.type(obj[i])
                    end
                end
            end
            return res
        elseif type(obj) == "string" then
            local res = {}
            if size then
                if type(size) == "string" then
                    if not partial_struct then error("missing partial structure for size field '" .. size .. "'") end
                    size = partial_struct[size]
                    if type(size) ~= "number" then error("size field '" .. self.size .. "' for array is not a number") end
                end
                if type(self.type) == "string" then
                    res = {self.type:rep(size):unpack(obj, pos)}
                    pos = res[size+1]
                    res[size+1] = nil
                else
                    for i = 1, size do
                        res[i], pos = self.type(obj, pos, partial_struct)
                    end
                end
            else
                local sz
                sz, pos = ("T"):unpack(obj, pos)
                if type(self.type) == "string" then
                    res = {self.type:rep(sz):unpack(obj, pos)}
                    pos = res[sz+1]
                    res[sz+1] = nil
                else
                    for i = 1, sz do
                        res[i], pos = self.type(obj, pos, partial_struct)
                    end
                end
            end
            return res, pos
        elseif obj == nil then
            local res = {}
            if type(size) == "number" then
                for i = 1, size do
                    if type(self.type) == "string" then res[i] = (self.type == "z" or self.type:sub(1, 1) == "c" or self.type:sub(1, 1) == "s") and "" or 0
                    else res[i] = self.type() end
                end
            end
            return res
        else error("bad argument #1 (expected string or table, got " .. type(obj) .. ")", 2) end
    end,
    __len = function(self)
        if type(self.size) ~= "number" then error("bad argument #1 (variable-length format)", 2) end
        if type(self.type) == "string" then return self.type:packsize() * self.size
        else return #self.type * self.size end
    end
}

local vlstr_mt = {
    __call = function(self, obj, pos, partial_struct)
        if not partial_struct then error("missing outer structure for size field '" .. self.size .. "'") end
        local size = partial_struct[self.size]
        if size == nil and pos == nil then size = #obj end
        if type(size) ~= "number" then error("size field '" .. self.size .. "' for array is not a number") end
        if type(obj) == "string" then
            return obj:sub(pos or 1, pos and pos + size - 1 or size) .. (#obj < size and ("\0"):rep(size - #obj) or ""), pos and pos + size
        elseif obj == nil then
            return ""
        else error("bad argument #1 (expected string or table, got " .. type(obj) .. ")", 2) end
    end,
    __len = function() error("bad argument #1 (variable-length format)", 2) end
}

local struct_mt = {
    __call = function(self, obj, pos)
        if type(obj) == "table" then
            local res = ""
            local fmt, par = "", {}
            for _, v in ipairs(self) do
                local vv = obj[v.name]
                if vv == nil then
                    for _, w in ipairs(self) do
                        if type(w.type) == "table" and (getmetatable(w.type) == array_mt or getmetatable(w.type) == vlstr_mt) and w.type.size == v.name then
                            vv = #obj[w.name]
                            break
                        end
                    end
                end
                if type(v.type) == "string" then
                    fmt, par[#par+1] = fmt .. v.type, vv
                else
                    if #fmt > 0 then res, fmt, par = res .. fmt:pack(table.unpack(par)), "", {} end
                    res = res .. v.type(vv, nil, obj)
                end
            end
            if #fmt > 0 then res = res .. fmt:pack(table.unpack(par)) end
            return res
        elseif type(obj) == "string" then
            pos = pos or 1
            local res, fmt, names = {}, "", {}
            for _, v in ipairs(self) do
                if type(v.type) == "string" then
                    fmt, names[#names+1] = fmt .. v.type, v.name
                else
                    if #fmt > 0 then
                        local r = table.pack(fmt:unpack(obj, pos))
                        for i = 1, r.n - 1 do res[names[i]] = r[i] end
                        pos = r[r.n]
                        fmt, names = "", {}
                    end
                    res[v.name], pos = v.type(obj, pos, res)
                end
            end
            if #fmt > 0 then
                local r = table.pack(fmt:unpack(obj, pos))
                for i = 1, r.n - 1 do res[names[i]] = r[i] end
                pos = r[r.n]
            end
            return res, pos
        elseif obj == nil then
            local res = {}
            for _, v in ipairs(self) do
                if type(v.type) == "string" then res[v.name] = (v.type == "z" or v.type:sub(1, 1) == "c" or v.type:sub(1, 1) == "s") and "" or 0
                else res[v.name] = v.type() end
            end
            return res
        else error("bad argument #1 (expected string or table, got " .. type(obj) .. ")", 2) end
    end,
    __len = function(self)
        local sum = 0
        local fmt = ""
        for _, v in ipairs(self) do
            if type(v.type) == "string" then fmt = fmt .. v.type
            else
                if #fmt > 0 then sum, fmt = sum + fmt:packsize(), "" end
                sum = sum + #v.type
            end
        end
        if #fmt > 0 then sum, fmt = sum + fmt:packsize(), "" end
        return sum
    end
}

local union_mt = {
    __call = function(self, obj, pos)
        if type(obj) == "table" then
            local res = ""
            local name = next(obj)
            local max = 0
            if not name or next(obj, name) then error("bad argument #1 (union table must contain exactly one entry)", 2) end
            for _, v in ipairs(self) do
                if type(v.type) == "string" then
                    if v.name == name then res = v.type:pack(obj[v.name]) end
                    max = math.max(max, v.type:packsize())
                else
                    if v.name == name then res = v.type(obj[v.name]) end
                    max = math.max(max, #v.type)
                end
            end
            return res .. ("\0"):rep(max - #res)
        elseif type(obj) == "string" then
            pos = pos or 1
            local res = {}
            local max = pos
            for _, v in ipairs(self) do
                local np
                if type(v.type) == "string" then res[v.name], np = v.type:unpack(obj, pos)
                else res[v.name], np = v.type(obj, pos) end
                max = math.max(max, np)
            end
            return res, max
        elseif obj == nil then
            return {}
        else error("bad argument #1 (expected string or table, got " .. type(obj) .. ")", 2) end
    end,
    __len = function(self)
        local max = 0
        for _, v in ipairs(self) do
            if type(v.type) == "string" then max = math.max(max, v.type:packsize())
            else max = math.max(max, #v.type) end
        end
        return max
    end
}

local enum_mt = {
    __call = function(self, obj, pos)
        if type(obj) == "string" then
            if self.encode[obj] then return ("I"):pack(self.encode[obj])
            else
                local res
                res, pos = ("I"):unpack(obj, pos)
                return self.decode[res], pos
            end
        elseif type(obj) == "number" then
            if self.decode[obj] then return ("I"):pack(obj)
            else error("Unknown enum value " .. tostring(obj), 2) end
        elseif obj == nil then
            return self.decode[0]
        else error("bad argument #1 (expected string or number, got " .. type(obj) .. ")", 2) end
    end,
    __len = function() return ("I"):packsize() end
}

function struct(tokens, pos, types)
    local s = {}
    while tokens[pos] ~= symbols['}'] do
        if not tokens[pos] then error("syntax error: expected '}' near <eof>", 2) end
        local ent = {}
        s[#s+1] = ent
        local tl = {}
        while type(tokens[pos]) == "table" and tokens[pos][1] < 10 do
            if tokens[pos] ~= keywords.const then tl[#tl+1] = tokens[pos] end
            pos = pos + 1
        end
        if #tl == 0 then
            if type(tokens[pos]) == "string" then
                ent.type = types[tokens[pos]]
                if not ent.type then error("compile error: undefined type " .. tostring(tokens[pos]), 3) end
                pos = pos + 1
            elseif tokens[pos] == keywords.struct then
                pos = pos + 1
                if type(tokens[pos]) == "string" then
                    ent.type = types.struct[tokens[pos]]
                    if not ent.type then error("compile error: undefined struct type " .. tostring(tokens[pos]), 3) end
                    pos = pos + 1
                elseif tokens[pos] == symbols['{'] then
                    ent.type, pos = struct(tokens, pos + 1, types)
                else error("syntax error near 'struct " .. tostring(tokens[pos]) .. "'", 3) end
            elseif tokens[pos] == keywords.union then
                pos = pos + 1
                if type(tokens[pos]) == "string" then
                    ent.type = types.union[tokens[pos]]
                    if not ent.type then error("compile error: undefined union type " .. tostring(tokens[pos]), 3) end
                    pos = pos + 1
                elseif tokens[pos] == symbols['{'] then
                    ent.type, pos = union(tokens, pos + 1, types)
                else error("syntax error near 'union " .. tostring(tokens[pos]) .. "'", 3) end
            elseif tokens[pos] == keywords.enum then
                pos = pos + 1
                assert(type(tokens[pos]) == "string", "syntax error near 'enum " .. tostring(tokens[pos+1]) .. "'")
                ent.type = types.enum[tokens[pos]] or types.int
                pos = pos + 1
            else error("syntax error near '" .. tostring(tokens[pos]) .. "'" .. pos .. #s, 3) end
        else
            ent.type = types[mktype(table.unpack(tl))]
            if not ent.type then error("syntax error: invalid type combination '" .. table.concat(tl, " ") .. "'", 3) end
        end
        local basetype = ent.type
        if basetype == "b" and tokens[pos] == symbols['*'] then ent.type, pos = "z", pos + 1 end
        if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 3) end
        ent.name = tokens[pos]
        pos = pos + 1
        if tokens[pos] == symbols['['] then
            local array = {}
            while tokens[pos] == symbols['['] do
                pos = pos + 1
                if tokens[pos] == symbols[']'] then
                    array[#array+1] = false
                else
                    if type(tokens[pos]) == "string" then
                        local found = false
                        for i = 1, #s - 1 do
                            if s[i].name == tokens[pos] then
                                if not ((type(s[i].type) == "string" and s[i].type:match "^[bBhHiIlLjJT]") or (type(s[i].type) == "table" and getmetatable(s[i].type) == enum_mt)) then
                                    error("syntax error: array length field '" .. tokens[pos] .. "' is not an integer", 3)
                                end
                                found = true
                                break
                            end
                        end
                        if not found then error("syntax error: array length field '" .. tokens[pos] .. "' is not defined", 3) end
                    elseif type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                    array[#array+1] = tokens[pos]
                    pos = pos + 1
                    if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                end
                pos = pos + 1
            end
            if ent.type == "b" and #array == 1 then
                if type(array[1]) == "string" then ent.type = setmetatable({size = array[1]}, vlstr_mt)
                else ent.type = "c" .. array[1] end
            else for i = #array, 1, -1 do ent.type = setmetatable({type = ent.type, size = array[i]}, array_mt) end end
        end
        while tokens[pos] == symbols[','] do
            local e = {type = basetype}
            s[#s+1] = e
            pos = pos + 1
            if basetype == "b" and tokens[pos] == symbols['*'] then e.type, pos = "z", pos + 1 end
            if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 3) end
            e.name = tokens[pos]
            pos = pos + 1
            if tokens[pos] == symbols['['] then
                local array = {}
                while tokens[pos] == symbols['['] do
                    pos = pos + 1
                    if tokens[pos] == symbols[']'] then
                        array[#array+1] = false
                    else
                        if type(tokens[pos]) == "string" then
                            local found = false
                            for i = 1, #s - 1 do
                                if s[i].name == tokens[pos] then
                                    if not ((type(s[i].type) == "string" and s[i].type:match "^[bBhHiIlLjJT]") or (type(s[i].type) == "table" and getmetatable(s[i].type) == enum_mt)) then
                                        error("syntax error: array length field '" .. tokens[pos] .. "' is not an integer", 3)
                                    end
                                    found = true
                                    break
                                end
                            end
                            if not found then error("syntax error: array length field '" .. tokens[pos] .. "' is not defined", 3) end
                        elseif type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                        array[#array+1] = tokens[pos]
                        pos = pos + 1
                        if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                    end
                    pos = pos + 1
                end
                if e.type == "b" and #array == 1 then
                    if type(array[1]) == "string" then e.type = setmetatable({size = array[1]}, vlstr_mt)
                    else e.type = "c" .. array[1] end
                else for i = #array, 1, -1 do e.type = setmetatable({type = e.type, size = array[i]}, array_mt) end end
            end
        end
        if tokens[pos] ~= symbols[';'] then error("syntax error: expected ';' near '" .. tostring(tokens[pos]) .. "'", 3) end
        pos = pos + 1
    end
    return setmetatable(s, struct_mt), pos + 1
end

function union(tokens, pos, types)
    local s = {}
    while tokens[pos] ~= symbols['}'] do
        if not tokens[pos] then error("syntax error: expected '}' near <eof>", 2) end
        local ent = {}
        s[#s+1] = ent
        local tl = {}
        while type(tokens[pos]) == "table" and tokens[pos][1] < 10 do
            if tokens[pos] ~= keywords.const then tl[#tl+1] = tokens[pos] end
            pos = pos + 1
        end
        if #tl == 0 then
            if type(tokens[pos]) == "string" then
                ent.type = types[tokens[pos]]
                if not ent.type then error("compile error: undefined type " .. tostring(tokens[pos]), 3) end
                pos = pos + 1
            elseif tokens[pos] == keywords.struct then
                pos = pos + 1
                if type(tokens[pos]) == "string" then
                    ent.type = types.struct[tokens[pos]]
                    if not ent.type then error("compile error: undefined struct type " .. tostring(tokens[pos]), 3) end
                    pos = pos + 1
                elseif tokens[pos] == symbols['{'] then
                    ent.type, pos = struct(tokens, pos + 1, types)
                else error("syntax error near 'struct " .. tostring(tokens[pos]) .. "'", 3) end
            elseif tokens[pos] == keywords.union then
                pos = pos + 1
                if type(tokens[pos]) == "string" then
                    ent.type = types.union[tokens[pos]]
                    if not ent.type then error("compile error: undefined union type " .. tostring(tokens[pos]), 3) end
                    pos = pos + 1
                elseif tokens[pos] == symbols['{'] then
                    ent.type, pos = union(tokens, pos + 1, types)
                else error("syntax error near 'union " .. tostring(tokens[pos]) .. "'", 3) end
            elseif tokens[pos] == keywords.enum then
                pos = pos + 1
                assert(type(tokens[pos]) == "string", "syntax error near 'enum " .. tostring(tokens[pos+1]) .. "'")
                ent.type = types.enum[tokens[pos]] or types.int
                pos = pos + 1
            else error("syntax error near '" .. tostring(tokens[pos]) .. "'", 3) end
        else
            ent.type = types[mktype(table.unpack(tl))]
            if not ent.type then error("syntax error: invalid type combination '" .. table.concat(tl, " ") .. "'", 3) end
        end
        local basetype = ent.type
        if basetype == "b" and tokens[pos] == symbols['*'] then error("compiler error: C strings are not allowed in unions") end
        if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 3) end
        ent.name = tokens[pos]
        pos = pos + 1
        if tokens[pos] == symbols['['] then
            local array = {}
            while tokens[pos] == symbols['['] do
                pos = pos + 1
                if tokens[pos] == symbols[']'] then
                    array[#array+1] = false
                else
                    if type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                    array[#array+1] = tokens[pos]
                    pos = pos + 1
                    if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                end
                pos = pos + 1
            end
            if ent.type == "b" and #array == 1 then ent.type = "c" .. array[1]
            else for i = #array, 1, -1 do ent.type = setmetatable({type = ent.type, size = array[i]}, array_mt) end end
        end
        while tokens[pos] == symbols[','] do
            local e = {type = basetype}
            s[#s+1] = e
            pos = pos + 1
            if basetype == "b" and tokens[pos] == symbols['*'] then error("compiler error: C strings are not allowed in unions") end
            if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 3) end
            e.name = tokens[pos]
            pos = pos + 1
            if tokens[pos] == symbols['['] then
                local array = {}
                while tokens[pos] == symbols['['] do
                    pos = pos + 1
                    if tokens[pos] == symbols[']'] then
                        array[#array+1] = false
                    else
                        if type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                        array[#array+1] = tokens[pos]
                        pos = pos + 1
                        if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                    end
                    pos = pos + 1
                end
                if e.type == "b" and #array == 1 then e.type = "c" .. array[1]
                else for i = #array, 1, -1 do e.type = setmetatable({type = e.type, size = array[i]}, array_mt) end end
            end
        end
        if tokens[pos] ~= symbols[';'] then error("syntax error: expected ';' near '" .. tostring(tokens[pos]) .. "'", 3) end
        pos = pos + 1
    end
    return setmetatable(s, union_mt), pos + 1
end

local function tokenize(str)
    local pos = str:find "%S"
    local tokens = {}
    while pos <= #str do
        local m, p = str:match("^([A-Za-z_][A-Za-z0-9_]*)()", pos)
        if m then
            tokens[#tokens+1], pos = keywords[m] or m, p
        else
            m, p = str:match("^([%*%[%]{};,=])()", pos)
            if m then
                tokens[#tokens+1], pos = symbols[m], p
            else
                m, p = str:match("^0([0-7]+)[Uu]?[Ll]?()", pos)
                if m then
                    tokens[#tokens+1], pos = tonumber(m, 8), p
                else
                    m, p = str:match("^0x(%x+)[Uu]?[Ll]?()", pos)
                    if m then
                        tokens[#tokens+1], pos = tonumber(m, 16), p
                    else
                        m, p = str:match("^0b([01]+)[Uu]?[Ll]?()", pos)
                        if m then
                            tokens[#tokens+1], pos = tonumber(m, 1), p
                        else
                            m, p = str:match("^(%d+)[Uu]?[Ll]?()", pos)
                            if m then
                                tokens[#tokens+1], pos = tonumber(m, 10), p
                            else
                                error("syntax error near '" .. str:sub(pos, pos + 5) .. "'", 3)
                            end
                        end
                    end
                end
            end
        end
        pos = str:find("%S", pos)
        if not pos then break end
    end
    return tokens
end

--- Defines a structure coder from C structure code.
--- 
--- See https://gist.github.com/MCJack123/2e60f0b1c01411f4fe91d902212e33c9 for
--- more information about how this works.
--- @param def string The C code to compile into types
--- @param types? table A table containing previously defined types; types will also be stored back into this table
--- @return fun(obj:string|any,pos:number|nil):any|string,number|nil result The coder for the last defined type, which can either take an object to encode (usually a table for a struct) and returns a string, or a string to decode and optionally a position to decode from and returns the decoded object + the next position to decode from
function serialization.struct(def, types)
    if type(def) ~= "string" then error("bad argument #1 (expected string, got " .. type(def) .. ")", 2) end
    if types ~= nil and type(types) ~= "table" then error("bad argument #2 (expected table, got " .. type(types) .. ")", 2) end
    types = types or {struct = {}, union = {}}
    if not types.struct then types.struct = {} end
    if not types.union then types.union = {} end
    if not types.enum then types.enum = {} end
    setmetatable(types, {__index = base_types})
    local tokens = tokenize(def)
    local pos = 1
    local last
    while pos < #tokens do
        if tokens[pos] == keywords.typedef then
            pos = pos + 1
            local tl = {}
            local tt
            while type(tokens[pos]) == "table" and tokens[pos][1] < 10 do
                if tokens[pos] ~= keywords.const then tl[#tl+1] = tokens[pos] end
                pos = pos + 1
            end
            if #tl == 0 then
                if type(tokens[pos]) == "string" then
                    tt = types[tokens[pos]]
                    if not tt then error("compile error: undefined type " .. tostring(tokens[pos]), 2) end
                    pos = pos + 1
                elseif tokens[pos] == keywords.struct then
                    pos = pos + 1
                    if type(tokens[pos]) == "string" then
                        tt = types.struct[tokens[pos]]
                        if not tt then
                            local name = tokens[pos]
                            pos = pos + 1
                            if tokens[pos] == symbols['{'] then tt, pos = struct(tokens, pos + 1, types)
                            else error("compile error: undefined struct type " .. name, 2) end
                            types.struct[name] = tt
                        else pos = pos + 1 end
                    elseif tokens[pos] == symbols['{'] then
                        tt, pos = struct(tokens, pos + 1, types)
                    else error("syntax error near 'struct " .. tostring(tokens[pos]) .. "'", 2) end
                elseif tokens[pos] == keywords.union then
                    pos = pos + 1
                    if type(tokens[pos]) == "string" then
                        tt = types.union[tokens[pos]]
                        if not tt then
                            local name = tokens[pos]
                            pos = pos + 1
                            if tokens[pos] == symbols['{'] then tt, pos = union(tokens, pos + 1, types)
                            else error("compile error: undefined union type " .. name, 2) end
                            types.union[name] = tt
                        else pos = pos + 1 end
                        pos = pos + 1
                    elseif tokens[pos] == symbols['{'] then
                        tt, pos = union(tokens, pos + 1, types)
                    else error("syntax error near 'union " .. tostring(tokens[pos]) .. "'", 2) end
                elseif tokens[pos] == keywords.enum then
                    pos = pos + 1
                    if tokens[pos] == symbols['{'] then
                        local enum = setmetatable({encode = {}, decode = {}}, enum_mt)
                        local n = 0
                        pos = pos + 1
                        while tokens[pos] ~= symbols['}'] do
                            if type(tokens[pos]) ~= "string" then error("syntax error: expected name near " .. tostring(tokens[pos]), 2) end
                            enum.encode[tokens[pos]] = n
                            enum.decode[n] = tokens[pos]
                            n = n + 1
                            pos = pos + 1
                            if tokens[pos] == symbols[','] then pos = pos + 1 end
                            if not tokens[pos] then error("syntax error: expected '}' near <eof>", 2) end
                        end
                        tt = enum
                    else
                        assert(type(tokens[pos]) == "string", "syntax error near 'enum " .. tostring(tokens[pos+1]) .. "'")
                        tt = types.enum[tokens[pos]] or types.int
                    end
                    pos = pos + 1
                else error("syntax error near '" .. tostring(tokens[pos]) .. "'", 2) end
            else
                tt = types[mktype(table.unpack(tl))]
                if not tt then error("syntax error: invalid type combination '" .. table.concat(tl, " ") .. "'", 2) end
            end
            local basett = tt
            if tt == "b" and tokens[pos] == symbols['*'] then tt, pos = "z", pos + 1 end
            if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 2) end
            local name = tokens[pos]
            pos = pos + 1
            if tokens[pos] == symbols['['] then
                local array = {}
                while tokens[pos] == symbols['['] do
                    pos = pos + 1
                    if tokens[pos] == symbols[']'] then
                        array[#array+1] = false
                    else
                        if type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                        array[#array+1] = tokens[pos]
                        pos = pos + 1
                        if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                    end
                    pos = pos + 1
                end
                if tt == "b" and #array == 1 then tt = "c" .. array[1]
                else for i = #array, 1, -1 do tt = setmetatable({type = tt, size = array[i]}, array_mt) end end
            end
            types[name] = tt
            while tokens[pos] == symbols[','] do
                local tt2 = basett
                pos = pos + 1
                if tt2 == "b" and tokens[pos] == symbols['*'] then tt2, pos = "z", pos + 1 end
                if type(tokens[pos]) ~= "string" then error("syntax error near " .. tostring(tokens[pos]), 2) end
                local name2 = tokens[pos]
                pos = pos + 1
                if tokens[pos] == symbols['['] then
                    local array = {}
                    while tokens[pos] == symbols['['] do
                        pos = pos + 1
                        if tokens[pos] == symbols[']'] then
                            array[#array+1] = false
                        else
                            if type(tokens[pos]) ~= "number" then error("syntax error near '[" .. tostring(tokens[pos]) .. "]'", 3) end
                            array[#array+1] = tokens[pos]
                            pos = pos + 1
                            if tokens[pos] ~= symbols[']'] then error("syntax error near '[" .. array[#array] .. tostring(tokens[pos]) .. "'", 3) end
                        end
                        pos = pos + 1
                    end
                    if tt2 == "b" and #array == 1 then tt2 = "c" .. array[1]
                    else for i = #array, 1, -1 do tt2 = setmetatable({type = tt2, size = array[i]}, array_mt) end end
                end
                types[name2] = tt2
            end
            if tokens[pos] ~= symbols[';'] then error("syntax error: expected ';' near '" .. tostring(tokens[pos]) .. "'", 2) end
            last = tt
            pos = pos + 1
        elseif tokens[pos] == keywords.struct then
            pos = pos + 1
            if type(tokens[pos]) == "string" then
                local name = tokens[pos]
                pos = pos + 1
                if tokens[pos] == symbols['{'] then last, pos = struct(tokens, pos + 1, types)
                else error("syntax error: expected '{' near '" .. tostring(tokens[pos]) .. '}', 2) end
                types.struct[name] = last
            elseif tokens[pos] == symbols['{'] then
                last, pos = struct(tokens, pos + 1, types)
            else error("syntax error near 'struct " .. tostring(tokens[pos]) .. "'", 3) end
        elseif tokens[pos] == keywords.union then
            pos = pos + 1
            if type(tokens[pos]) == "string" then
                local name = tokens[pos]
                pos = pos + 1
                if tokens[pos] == symbols['{'] then last, pos = union(tokens, pos + 1, types)
                else error("syntax error: expected '{' near '" .. tostring(tokens[pos]) .. '}', 2) end
                types.union[name] = last
            elseif tokens[pos] == symbols['{'] then
                last, pos = union(tokens, pos + 1, types)
            else error("syntax error near 'struct " .. tostring(tokens[pos]) .. "'", 3) end
        elseif tokens[pos] == keywords.enum then
            pos = pos + 1
            if type(tokens[pos]) ~= "string" then error("syntax error: expected name near 'enum'", 2) end
            local name = tokens[pos]
            pos = pos + 1
            local enum = setmetatable({encode = {}, decode = {}}, enum_mt)
            local n = 0
            if tokens[pos] ~= symbols['{'] then error("syntax error: expected '{' near 'enum'", 2) end
            pos = pos + 1
            while tokens[pos] ~= symbols['}'] do
                if type(tokens[pos]) ~= "string" then error("syntax error: expected name near " .. tostring(tokens[pos]), 2) end
                if tokens[pos+1] == symbols['='] and type(tokens[pos+2]) == "number" then
                    n = tokens[pos+2]
                    enum.encode[tokens[pos]] = n
                    enum.decode[n] = tokens[pos]
                    n = n + 1
                    pos = pos + 3
                else
                    enum.encode[tokens[pos]] = n
                    enum.decode[n] = tokens[pos]
                    n = n + 1
                    pos = pos + 1
                end
                if tokens[pos] == symbols[','] then pos = pos + 1 end
                if not tokens[pos] then error("syntax error: expected '}' near <eof>", 2) end
            end
            pos = pos + 1
            if tokens[pos] ~= symbols[';'] then error("syntax error: expected ';' near '" .. tostring(tokens[pos]) .. "'", 2) end
            types.enum[name] = enum
            last = enum
            pos = pos + 1
        elseif tokens[pos] == symbols[';'] then pos = pos + 1
        else error("compiler error: unexpected token " .. tostring(tokens[pos]), 2) end
    end
    return last
end

return serialization