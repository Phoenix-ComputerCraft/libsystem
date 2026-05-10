--- The IPC module provides functions for sending messages to other processes.
--
-- @module system.ipc

local expect = require "expect"
local util = require "util"

local ipc = {}

--- Constants for signal numbers
ipc.signal = {
    SIGHUP = 1,
    SIGINT = 2,
    SIGQUIT = 3,
    SIGTRAP = 5,
    SIGABRT = 6,
    SIGKILL = 9,
    SIGPIPE = 13,
    SIGTERM = 15,
    SIGCONT = 18,
    SIGSTOP = 19,
    SIGTTIN = 21,
    SIGTTOU = 22,
}

--- Sends a basic signal to a process.
-- @tparam number pid The PID of the process to send to
-- @tparam number signal The signal to send to the process
function ipc.kill(pid, signal)
    expect(1, pid, "number")
    expect(2, signal, "number")
    return util.syscall.kill(pid, signal)
end

--- Sets the handler for a signal.
-- @tparam number signal The signal to modify
-- @tparam function|nil fn The function to call, or `nil` to remove
function ipc.sigaction(signal, fn)
    expect(1, signal, "number")
    expect(2, fn, "function", "nil")
    return util.syscall.signal(signal, fn)
end

--- Sends a remote event to a process.
-- @tparam number pid The PID of the process to send to
-- @tparam string event The event name to send
-- @tparam table param The parameter table to send with the event
-- @treturn boolean Whether the event was sent
function ipc.sendEvent(pid, event, param)
    expect(1, pid, "number")
    expect(2, event, "string")
    expect(3, param, "table")
    return util.syscall.sendEvent(pid, event, param)
end

--- Registers the current process as the receiver of a service name.
-- @tparam string name The service name to register for
-- @treturn boolean Whether the service was registered
-- @see lookup To find a process for a service
function ipc.register(name)
    expect(1, name, "string")
    return util.syscall.register(name)
end

--- Returns the ID of the process that receives a service name.
-- @tparam string name The service to lookup
-- @treturn number|nil The PID of the process that owns it (if available)
-- @see register To register your process for a service
function ipc.lookup(name)
    expect(1, name, "string")
    return util.syscall.lookup(name)
end

--- Sends an event to the owner of a service.
-- @tparam string name The service to send to
-- @tparam string event The event name to send
-- @tparam table param The parameter table to send with the event
-- @treturn boolean Whether the event was sent
function ipc.sendServiceEvent(name, event, param)
    expect(1, name, "string")
    expect(2, event, "string")
    expect(3, param, "table")
    local pid = util.syscall.lookup(name)
    if not pid then return false end
    return util.syscall.sendEvent(pid, event, param)
end

--- Waits for a remote event, filtering for processes or event names, with an optional timeout.
-- @tparam[opt] number pid The PID to wait for an event from
-- @tparam[opt] string event The event to filter for
-- @tparam[opt] number timeout The maximum number of seconds to wait for
-- @treturn[1] string The event name received
-- @treturn[1] table The parameters for the event
-- @treturn[2] nil If the function timed out
function ipc.receiveEvent(pid, event, timeout)
    expect(1, pid, "number", "nil")
    expect(2, event, "string", "nil")
    expect(3, timeout, "number", "nil")
    local tm
    if timeout then tm = util.timer(timeout) end
    while true do
        local ev, param = coroutine.yield()
        if ev == "timer" and param.id == tm then return nil
        elseif ev == "remote_event" and (pid == nil or pid == param.sender) and (event == nil or event == param.type) then
            if tm then util.cancel(tm) end
            return param.type, param.data
        end
    end
end

---@class ipc.socket
local socket = {}
local socket_mt = {__index = socket, __name = "socket"}

function socket:status()
    if self.closed then return "closed"
    else return "open" end
end

function socket:close()
    self.closed = true
end

function socket:read(fmt, ...)
    expect(1, fmt, "string", "number", "nil")
    local _, param = ipc.receiveEvent(self.pid, "libsystem.socket_message." .. self.name)
    local retval
    if fmt == nil or fmt == "a" or fmt == "*a" then retval = param.data
    elseif type(fmt) == "number" then retval = tostring(param.data):sub(1, fmt)
    else
        fmt = fmt:gsub("^%*", "")
        if fmt == "n" then retval = tonumber(param.data)
        else
            local s = tostring(param.data)
            if fmt == "l" then retval = s:match("^[^\n]*")
            elseif fmt == "L" then retval = s:match("^[^\n]*\n?")
            else error("invalid format " .. fmt, 2) end
        end
    end
    if select("#", ...) > 0 then return retval, self:read(...)
    else return retval end
end

function socket:write(obj, ...)
    ipc.sendEvent(self.pid, "libsystem.socket_message." .. self.name, {data = obj})
    if select("#", ...) > 0 then return self:write(...) end
end

--- Creates a named socket to another process.
--- 
--- Sockets are based on top of the remote event subsystem, sending messages
--- through specially named events. They implement the network handle interface
--- and as such can be used instead of a network handle (though note that these
--- sockets have no buffer and as such should not be used for continuous streams
--- of data, as a network handle often is used for). Sockets will only receive
--- messages from the same sender PID and socket name, so they can be isolated
--- from other sockets.
--- 
---@param name string The name of the socket. This must be the same on both ends.
---@param pid number|nil The PID to connect to, or `nil` to wait for a connection
---@return ipc.socket socket The new socket handle
function ipc.socket(name, pid)
    expect(1, name, "string")
    if expect(2, pid, "number", "nil") then
        ipc.sendEvent(pid, "libsystem.socket_connect." .. name, {pid = util.syscall.getpid()})
        return setmetatable({pid = pid, name = name}, socket_mt)
    else
        while true do
            local _, param = ipc.receiveEvent(nil, "libsystem.socket_connect." .. name)
            if type(param.pid) == "number" then return setmetatable({pid = param.pid, name = name}, socket_mt) end
        end
    end
end

return ipc
