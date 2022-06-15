--- The hardware module implements functions for operating on peripherals and
-- other hardware devices.
--
-- @module hardware

local expect = require "expect"
local util = require "util"

local hardware = {}

--- Wraps a device into an indexable object, allowing accessing properties and
-- methods of the device by indexing the table.
-- If an object is passed, this simply re-wraps the device in a new object.
-- @tparam string device The device specifier or object to wrap
-- @treturn device The wrapped device
-- @usage Wrap a device, use a property, and call a method:
--     
--     local computer = hardware.wrap("/")
--     print(computer.isOn)
--     computer.label = "My Computer"
--     computer:reboot()
function hardware.wrap(device)
    expect(1, device, "string", "device")
    local info = util.syscall.devinfo(device)
    if not info then return nil end
    local methods, properties = util.syscall.devmethods(device), util.syscall.devproperties(device)
    for _, v in ipairs(properties) do properties[v] = true end
    local retval = {}
    for _, v in ipairs(methods) do retval[v] = function(self, ...) return util.syscall.devcall(device, v, ...) end end
    return setmetatable(retval, {
        __name = "device",
        uuid = info.uuid,
        __index = function(self, idx)
            if type(idx) == "string" and properties[idx] then return util.syscall.devcall(device, "get" .. idx:gsub("^.", string.upper)) end
        end,
        __newindex = function(self, idx, val)
            if type(idx) == "string" and properties[idx] and methods["set" .. idx:gsub("^.", string.upper)] then return util.syscall.devcall(device, "set" .. idx:gsub("^.", string.upper), val) end
        end,
        __tostring = function(self)
            return "wrapped device: " .. (info.displayName or info.uuid)
        end
    })
end

--- Returns a list of wrapped devices that implement the specified type.
-- @tparam string type The type to search for
-- @treturn device... The devices found, or `nil` if none were found
-- @see wrap For wrapping a single device by path
function hardware.find(type)
    expect(1, type, "string")
    local retval = {}
    for i, v in ipairs{util.syscall.devfind(type)} do retval[i] = hardware.wrap(v) end
    return table.unpack(retval)
end

--- Returns a list of device paths that match the device specifier or object.
-- If an absolute path is specified, this returns the same path back.
-- If a device object is specified, this returns the path to the device.
-- @tparam string|device device The device specifier or object to read
-- @treturn string... The paths that match the specifier or device object.
function hardware.path(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devlookup(device)
    else return util.syscall.devlookup(getmetatable(device).uuid) end
end

--- Returns whether the device implements the specified type.
-- @tparam string|device device The device specifier or object to query
-- @tparam string type The type to check for
-- @treturn boolean Whether the device implements the type
function hardware.hasType(device, type)
    expect(1, device, "string", "device")
    local info
    if type(device) == "string" then info = util.syscall.devinfo(device)
    else info = util.syscall.devinfo(getmetatable(device).uuid) end
    if not info then error("No such device", 2) end
    return info.types[type] ~= nil
end

--- Returns a table of information about the specified device.
-- @tparam string|device device The device specifier or object to query
-- @treturn HWInfo|nil The hardware info table, or `nil` if no device was found
function hardware.info(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devinfo(device)
    else return util.syscall.devinfo(getmetatable(device).uuid) end
end

--- Returns a list of methods implemented by this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The methods available to call on this device
function hardware.methods(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devmethods(device)
    else return util.syscall.devmethods(getmetatable(device).uuid) end
end

--- Returns a list of properties implemented by this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The properties available on this device
function hardware.properties(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devproperties(device)
    else return util.syscall.devproperties(getmetatable(device).uuid) end
end

--- Returns a list of children of this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The names of children of the device
function hardware.children(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devchildren(device)
    else return util.syscall.devchildren(getmetatable(device).uuid) end
end

--- Calls a method on a device.
-- @tparam string|device device The device specifier or object to call on
-- @tparam string method The method to call
-- @tparam any ... Any arguments to pass to the method
-- @treturn any... The return values from the method
function hardware.call(device, method, ...)
    expect(1, device, "string", "device")
    expect(2, method, "string")
    if type(device) == "string" then return util.syscall.devcall(device, method, ...)
    else return util.syscall.devcall(getmetatable(device).uuid, method, ...) end
end

--- Toggles whether this process should receive events from the device.
-- @tparam string|device device The device specifier or object to modify
-- @tparam[opt=true] boolean state Whether to allow events
function hardware.listen(device, state)
    expect(1, device, "string", "device")
    expect(2, state, "boolean", "nil")
    if type(device) == "string" then return util.syscall.devlisten(device, state)
    else return util.syscall.devlisten(getmetatable(device).uuid, state) end
end

--- Locks the device from being called on or listened to by other processes.
-- @tparam string|device device The device specifier or object to modify
-- @tparam[opt=true] boolean wait Whether to wait for the device to unlock if
-- it's currently locked by another process
-- @treturn boolean Whether the current process now owns the lock
-- @see unlock To unlock the device afterward
function hardware.lock(device, wait)
    expect(1, device, "string", "device")
    expect(2, wait, "boolean", "nil")
    if type(device) == "string" then return util.syscall.devlock(device, wait)
    else return util.syscall.devlock(getmetatable(device).uuid, wait) end
end

--- Unlocks the device after previously locking it.
-- @tparam string|device device The device specifier or object to modify
-- @see lock To lock the device
function hardware.unlock(device)
    expect(1, device, "string", "device")
    if type(device) == "string" then return util.syscall.devunlock(device)
    else return util.syscall.devunlock(getmetatable(device).uuid) end
end

local function makeTree(path)
    local info = hardware.info(path or "/")
    if not info then return nil end
    path = path or ""
    return setmetatable({}, {
        __name = "devicetree",
        uuid = info.uuid,
        __index = function(self, idx)
            return makeTree(path .. "/" .. idx)
        end,
        __newindex = function() end
    })
end

--- A table that allows accessing device object pointers in a tree. This is
-- simply syntax sugar for real paths.
-- @usage To access the left redstone signal
--     
--     local device = hardware.wrap(hardware.tree.redstone.left)
--     print(device.input)
hardware.tree = makeTree()

return hardware