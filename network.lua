local util = require "util"
local expect = require "expect"

--- The network module implements functions for making and hosting connections
--- with local and Internet-connected computers, as well as managing the network
--- stack configuration.
---
--- !doctype module
--- @class system.network
local network = {route = {}, arp = {}}

--- Parses a URI into its components.
--- @param uri string The URI to parse
--- @return table result The components of the URI
function network.parseURI(uri)
    local info = {scheme = ""}
    for c in uri:gmatch "." do
        if info.fragment then
            if c:match "[%w%-%._~%%@:/!%$&'%(%)%*%+,;=/?]" then info.fragment = info.fragment .. c
            else error("Invalid URI", 3) end
        elseif info.query then
            if c == "#" then info.fragment = ""
            elseif c:match "[%w%-%._~%%@:/!%$&'%(%)%*%+,;=/?]" then info.query = info.query .. c
            else error("Invalid URI", 3) end
        elseif info.path then
            if c == "/" and info.path == "/" and not info.host then info.path, info.host = nil, ""
            elseif c == "?" then info.query = ""
            elseif c == "#" then info.fragment = ""
            elseif c:match "[%w%-%._~%%@:/!%$&'%(%)%*%+,;=/]" then info.path = info.path .. c
            else error("Invalid URI", 3) end
        elseif info.port then
            if tonumber(c) then info.port = info.port .. c
            elseif c == "/" then info.path = "/"
            else error("Invalid URI", 3) end
        elseif info.host then
            if c == "@" and not info.user then info.user, info.host = info.host, ""
            elseif c == ":" then info.port = ""
            elseif c == "/" then info.path = "/"
            elseif c:match "[%w%-%._~%%/!%$&'%(%)%*%+,;=]" then info.host = info.host .. c
            else error("Invalid URI", 3) end
        else
            if c == ":" then info.path = ""
            elseif c:match(info.scheme == "" and "[%a%+%-%.]" or "[%w%+%-%.]") then info.scheme = info.scheme .. c
            else error("Invalid URI", 3) end
        end
    end
    if info.port then info.port = tonumber(info.port) end
    return info
end

--- Creates a new connection to a remote server.
--- @param options string|table The URI to connect with, or a table of options (see the connect syscall docs for more information)
--- @return system.network.Handle result A handle to the connection
function network.connect(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then expect.field(options, "url", "string") end
    return util.syscall.connect(options)
end

--- Connects to an HTTP(S) server, sends a GET request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.get(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    elseif not options:match("^https?://") then error("Invalid scheme", 2) end
    local handle = util.syscall.connect(options)
    handle:write()
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a GET request, waits for a response,
--- and returns the data received after closing the connection.
--- @param url string The URL to connect to
--- @param headers? table Any headers to send in the request
--- @return string|nil data The response data sent from the server, or `nil` if the connection failed
--- @return number|string code The HTTP response code for the response, or an error describing why the connection failed
function network.getData(url, headers)
    expect(1, url, "string")
    expect(2, headers, "table", "nil")
    if not url:match("^https?://") then error("Invalid scheme", 2) end
    local handle = util.syscall.connect{url = url, encoding = "binary", headers = headers}
    handle:write()
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then
                local data = handle:read("*a")
                local code = handle:responseCode()
                handle:close()
                return data, code
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a HEAD request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.head(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "HEAD"
    local handle = util.syscall.connect(options)
    handle:write()
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends an OPTIONS request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.options(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "OPTIONS"
    local handle = util.syscall.connect(options)
    handle:write()
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a POST request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @param data string The data to send to the server
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.post(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "POST"
    local handle = util.syscall.connect(options)
    handle:write(data)
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a PUT request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @param data string The data to send to the server
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.put(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "PUT"
    local handle = util.syscall.connect(options)
    handle:write(data)
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a DELETE request and waits for a response.
--- @param options string|table The URL to connect to, or a table of options (see the connect syscall docs for more information)
--- @param data string The data to send to the server
--- @return system.network.Handle|nil The handle to the response data, or `nil` if the connection failed
--- @return nil|string An error describing why the connection failed
function network.delete(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string", "nil")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "DELETE"
    local handle = util.syscall.connect(options)
    handle:write(data)
    while true do
        local event, param = coroutine.yield()
        if event == "handle_status_change" and param.id == handle.id then
            if param.status == "open" then return handle
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

function network.listen(uri)
    expect(1, uri, "string")
    return util.syscall.listen(uri)
end

function network.unlisten(uri)
    expect(1, uri, "string")
    return util.syscall.unlisten(uri)
end

function network.ipconfig(device, info)
    expect(1, device, "string", "table")
    expect(2, info, "table", "nil")
    if info then
        expect.field(info, "ip", "string", "number", "nil")
        expect.field(info, "netmask", "string", "number", "nil")
        expect.field(info, "up", "boolean", "nil")
    end
    return util.syscall.ipconfig(device, info)
end

function network.route.list(num)
    expect(1, num, "number", "nil")
    return util.syscall.routelist(num)
end

function network.route.add(options)
    expect(1, options, "table")
    expect.field(options, "table", "number", "nil")
    expect.field(options, "source", "string")
    expect.field(options, "sourceNetmask", "number")
    expect.field(options, "action", "string")
    expect.field(options, "device", "string", not (options.action == "local" or options.action == "unicast" or options.action == "broadcast") and "nil" or nil)
    expect.field(options, "destination", "string", options.action ~= "unicast" and "nil" or nil)
    return util.syscall.routeadd(options)
end

function network.route.remove(source, mask, num)
    expect(1, source, "string")
    expect(2, mask, "number")
    expect(3, num, "number", "nil")
    return util.syscall.routedel(source, mask, num)
end

function network.arp.list(device)
    expect(1, device, "string")
    return util.syscall.arplist(device)
end

function network.arp.set(device, ip, id)
    expect(1, device, "string")
    expect(2, ip, "string")
    expect(3, id, "number", "nil")
    return util.syscall.arpset(device, ip, id)
end

function network.control(ip, type, err)
    expect(1, ip, "string")
    expect(2, type, "string")
    expect(3, err, "string", "nil")
    return util.syscall.netcontrol(ip, type, err)
end

function network.events(state)
    expect(1, state, "boolean", "nil")
    return util.syscall.netevent(state)
end

function network.checkURI(uri)
    expect(1, uri, "string")
    return util.syscall.checkuri(uri)
end

function network.urlEncode(str)
    expect(1, str, "string")
    return str:gsub("\n", "\r\n")
        :gsub("([^A-Za-z0-9 %-%_%.])", function(c)
            local n = c:byte()
            if n < 128 then return ("%%%02X"):format(n)
            else return ("%%%02X%%%02X"):format(bit32.rshift(n, 6) + 0xC0, bit32.band(n, 0x3F) + 0x80) end
        end)
        :gsub(" ", "+")
end

--- !doctype class
--- @class system.network.Handle: file*
local Handle = {}

--- Returns the status of the handle.
--- @return "ready"|"connecting"|"open"|"closed"|"error" status The status of the handle
--- @return string|nil error If in error state, an error message associated with the status
function Handle:status() return "error" end

--- !doctype class
--- @class system.network.HTTPHandle: system.network.Handle
local HTTPHandle = {}

--- Returns the response headers for the request.
--- @return {[string]: string}|nil headers The headers in the response
function HTTPHandle:responseHeaders() end

--- Returns the response code for the request.
--- @return number|nil code The code from the response
function HTTPHandle:responseCode() end

return network