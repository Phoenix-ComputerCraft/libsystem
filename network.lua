--- The network module implements functions for making and hosting connections
-- with local and Internet-connected computers, as well as managing the network
-- stack configuration.
--
-- @module system.network

local util = require "util"
local expect = require "expect"

local network = {route = {}, arp = {}}

--- Creates a new connection to a remote server.
-- @tparam string|table options The URI to connect with, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn Handle A handle to the connection
function network.connect(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then expect.field(options, "url", "string") end
    return util.syscall.connect(options)
end

--- Connects to an HTTP(S) server, sends a GET request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
-- and returns the data received after closing the connection.
-- @tparam string url The URL to connect to
-- @tparam[opt] table headers Any headers to send in the request
-- @treturn[1] string The response data sent from the server
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
                handle:close()
                return data
            elseif param.status == "error" then return nil, select(2, handle:status()) end
        end
    end
end

--- Connects to an HTTP(S) server, sends a HEAD request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam string data The data to send to the server
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam string data The data to send to the server
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam[opt] string data The data to send to the server, if required
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
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

return network