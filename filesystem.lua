--- The filesystem module implements common operations for working with the
-- filesystem, including wrappers for syscalls.
--
-- @module system.filesystem

local util = require "util"
local expect = require "expect"

local filesystem = {}

--- Opens a file for reading or writing.
-- @tparam string path The path to the file to open
-- @tparam string mode The mode to open the file in: [rwa]b?
-- @treturn[1] FileHandle The file handle, which has the same functions as CraftOS file handles
-- @treturn[2] nil If the file could not be opened
-- @treturn[2] string An error message describing why the file couldn't be opened
function filesystem.open(path, mode)
    expect(1, path, "string")
    expect(2, mode, "string")
    return util.syscall.open(path, mode)
end

--- Returns a list of files in a directory.
-- @tparam string path The path to query
-- @treturn table A list of files and folders in the directory
function filesystem.list(path)
    expect(1, path, "string")
    return util.syscall.list(path)
end

--- Returns a table with various information about a file or directory.
-- @tparam string path The path to query
-- @tparam[opt=false] boolean nolink Whether to not resolve links to the file
-- @treturn FileStat A table with information about the path
function filesystem.stat(path, nolink)
    expect(1, path, "string")
    expect(2, nolink, "nil", "boolean")
    return util.syscall.stat(path, nolink)
end

--- Deletes a file or directory at a path, removing any subentries if present.
-- @tparam string path The path to remove
function filesystem.remove(path)
    expect(1, path, "string")
    return util.syscall.remove(path)
end

--- Moves a file or directory on the same filesystem.
-- @tparam string from The original file to move
-- @tparam string to The new path for the file
function filesystem.rename(from, to)
    expect(1, from, "string")
    expect(2, to, "string")
    return util.syscall.rename(from, to)
end

--- Creates a directory, making any parent paths that don't exist.
-- @tparam string path The directory to create
function filesystem.mkdir(path)
    expect(1, path, "string")
    return util.syscall.mkdir(path)
end

--- Creates a (symbolic) link to a file.
-- @tparam string path The path of the new link
-- @tparam string location The location to point the link to
function filesystem.link(path, location)
    expect(1, path, "string")
    expect(2, location, "string")
    return util.syscall.link(path, location)
end

--- Creates a FIFO.
-- @tparam string path The FIFO to create
function filesystem.mkfifo(path)
    expect(1, path, "string")
    return util.syscall.mkfifo(path)
end

--- Changes the permissions (mode) of the file at a path.
-- @tparam string path The path to modify
-- @tparam string|nil user The user to modify, or nil to modify world permissions
-- @tparam number|string|{read?=boolean,write?=boolean,execute?=boolean} mode The new permissions, as either an octal bitmask, a string in the format "[+-=][rwx]+" or "[r-][w-][x-]", or a table with the permissions to set (any `nil` arguments are left unset).
function filesystem.chmod(path, user, mode)
    expect(1, path, "string")
    expect(2, user, "string", "nil")
    expect(3, mode, "number", "string", "table")
    if type(mode) == "string" and not mode:match "^[%+%-=][rwxs]+$" and not mode:match "^[r%-][w%-][xs%-]$" then
        error("bad argument #3 (invalid mode)", 2)
    elseif type(mode) == "table" then
        expect.field(mode, "read", "boolean", "nil")
        expect.field(mode, "write", "boolean", "nil")
        expect.field(mode, "execute", "boolean", "nil")
    end
    return util.syscall.chmod(path, user, mode)
end

--- Changes the owner of a file or directory.
-- @tparam string path The path to modify
-- @tparam string user The new owner of the file
function filesystem.chown(path, user)
    expect(1, path, "string")
    expect(2, user, "string")
    return util.syscall.chown(path, user)
end

--- Changes the root directory of the current and future child processes.
-- This function requires root.
-- @tparam string path The new root path to change to
function filesystem.chroot(path)
    expect(1, path, "string")
    return util.syscall.chroot(path)
end

--- Mounts a filesystem of the specified type to a directory.
-- @tparam string type The type of filesystem to mount
-- @tparam string src The source of the mount (depends on the FS type)
-- @tparam string dest The destination directory to mount to
-- @tparam[opt] table options A table of options to pass to the filesystem
function filesystem.mount(type, src, dest, options)
    expect(1, type, "string")
    expect(2, src, "string")
    expect(3, dest, "string")
    expect(4, options, "table", "nil")
    return util.syscall.mount(type, src, dest, options)
end

--- Unmounts a mounted filesystem.
-- @tparam string path The filesystem to unmount
function filesystem.unmount(path)
    expect(1, path, "string")
    return util.syscall.unmount(path)
end

--- Returns a list of mounts currently available.
-- @treturn [{path:string,type:string,source:string,options:table}] A list of mounts and their properties.
function filesystem.mountlist()
    return util.syscall.mountlist()
end

--- Registers the process to receive filesystem events for a path. Note that this is not recursive.
-- @tparam string path The path to register for
-- @tparam[opt] boolean enabled Whether to enable events (defaults to true)
function filesystem.fsevent(path, enabled)
    expect(1, path, "string")
    expect(2, enabled, "boolean", "nil")
    return util.syscall.fsevent(path, enabled)
end

--- Combines the specified path components into a single path, canonicalizing any links and ./.. paths.
-- @tparam string ... The path components to combine
-- @treturn string The combined and canonicalized path
function filesystem.combine(...)
    return util.syscall.combine(...)
end

--- Gets the absolute path from a path string.
-- @tparam string path The path to convert
-- @treturn string An absolute path pointing to the file
function filesystem.absolute(path)
    expect(1, path, "string")
    path = filesystem.combine(path)
    if path:sub(1, 1) == "/" then return path end
    return filesystem.combine(util.syscall.getcwd(), path)
end

--- Copies a file or directory.
-- @tparam string from The path to copy from
-- @tparam string to The path to copy to
-- @tparam[opt] boolean preserve Whether to preserve permissions when copying
function filesystem.copy(from, to, preserve)
    expect(1, from, "string")
    expect(2, to, "string")
    local stat = assert(filesystem.stat(from), from .. ": No such file or directory")
    if stat.type == "directory" then
        local list = filesystem.list(from)
        filesystem.mkdir(to)
        for _, v in ipairs(list) do filesystem.copy(filesystem.combine(from, v), filesystem.combine(to, v)) end
    else
        local fromfile, err = filesystem.open(from, "rb")
        if not fromfile then error(err, 2) end
        local tofile, err = filesystem.open(to, "wb")
        if not tofile then fromfile.close() error(err, 2) end
        repeat
            local buf = fromfile.read(512)
            if buf then tofile.write(buf) end
        until not buf
        tofile.close()
        fromfile.close()
    end
    if preserve then
        filesystem.chmod(to, nil, stat.worldPermissions)
        for k, v in pairs(stat.permissions) do filesystem.chmod(to, k, v) end
        if stat.owner then filesystem.chown(to, stat.owner) end
        if stat.setuser then pcall(filesystem.chmod, to, stat.owner, "+s") end
    end
end

--- Moves a file or directory, allowing cross-filesystem operations.
-- @tparam string from The path to move from
-- @tparam string to The path to move to
function filesystem.move(from, to)
    expect(1, from, "string")
    expect(2, to, "string")
    local fromstat = assert(filesystem.stat(from, true), "File not found")
    local tostat = filesystem.stat(to)
    if tostat then error("File already exists", 2) end
    local path = filesystem.dirname(to)
    repeat tostat, path = filesystem.stat(path), filesystem.dirname(path) until tostat
    if fromstat.type == "directory" then
        local list = filesystem.list(from)
        filesystem.mkdir(to)
        for _, v in ipairs(list) do filesystem.move(filesystem.combine(from, v), filesystem.combine(to, v)) end
    elseif fromstat.mountpoint == tostat.mountpoint then
        filesystem.rename(from, to)
    else
        -- try to move without using more space: delete the old file before writing the new one
        local fromfile, err = filesystem.open(from, "rb")
        if not fromfile then error(err, 2) end
        local data = fromfile.readAll()
        fromfile.close()
        local tofile, err = filesystem.open(to, "wb")
        if not tofile then error(err, 2) end
        filesystem.remove(from)
        if data then tofile.write(data) end
        tofile.close()
    end
    filesystem.chmod(to, nil, fromstat.worldPermissions)
    for k, v in pairs(fromstat.permissions) do filesystem.chmod(to, k, v) end
    if fromstat.owner then filesystem.chown(to, fromstat.owner) end
    if fromstat.setuser then pcall(filesystem.chmod, to, fromstat.owner, "+s") end
end

--- Returns the file name for a path.
-- @tparam string path The path to use
-- @treturn string The file name of the path
function filesystem.basename(path)
    expect(1, path, "string")
    return filesystem.combine(path):match "[^/]*$"
end

--- Returns the parent directory for a path.
-- @tparam string path The path to use
-- @treturn string The parent directory of the path
function filesystem.dirname(path)
    expect(1, path, "string")
    local p = filesystem.combine(path):match "^(.*)/[^/]*$"
    if p == "" or p == nil then
        if path:sub(1, 1) == "/" then return "/"
        else return "." end
    else return p end
end

local function aux_find(options, pathc, i)
    if i > #pathc then return {} end
    local pathc_regex = "^" .. pathc[i]:gsub("[%^%$%(%)%%%.%+%-]", "%%%1"):gsub("%*", ".*"):gsub("%?", "."):gsub("%[!", "[^") .. "$"
    local nextOptions = {}
    for _, opt in ipairs(options) do
        local ok, possible_paths = pcall(filesystem.list, opt)
        if ok then
            for _, path in ipairs(possible_paths) do
                if path:match(pathc_regex) then
                    nextOptions[#nextOptions+1] = filesystem.combine(opt, path)
                end
            end
        end
    end
    if i + 1 > #pathc then return nextOptions end
    return aux_find(nextOptions, pathc, i + 1)
end

--- Searches the filesystem for paths matching a glob-style wildcard.
-- @tparam string wildcard The pathspec to match
-- @treturn table A list of matching file paths
function filesystem.find(wildcard)
    expect(1, wildcard, "string")
    local parts = {}
    for p in wildcard:gmatch("[^/]+") do parts[#parts+1] = p end
    local retval = aux_find({wildcard:sub(1, 1) == "/" and "/" or "."}, parts, 1)
    table.sort(retval)
    return retval
end

--- Convenience function for determining whether a file exists.
-- This simply checks that @{stat} does not return `nil`.
-- @tparam string path The path to check
-- @treturn boolean Whether the path exists
function filesystem.exists(path)
    expect(1, path, "string")
    return filesystem.stat(path) ~= nil
end

--- Returns whether the path exists and is a file.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a file
function filesystem.isFile(path)
    expect(1, path, "string")
    local s = filesystem.stat(path)
    if not s then return false end
    return s.type == "file"
end

--- Returns whether the path exists and is a directory.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a directory
function filesystem.isDir(path)
    expect(1, path, "string")
    local s = filesystem.stat(path)
    if not s then return false end
    return s.type == "directory"
end

--- Returns whether the path exists and is a link.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a link
function filesystem.isLink(path)
    expect(1, path, "string")
    local s = filesystem.stat(path)
    if not s then return false end
    return s.type == "link"
end

--- Returns the effective permissions on a file or stat entry for the selected user.
-- @tparam string|FileStat file The file path or stat to check
-- @tparam[opt] string user The user to check for (defaults to the current user)
-- @treturn {read:boolean,write:boolean,execute:boolean}|nil The permissions for the user, or `nil` if the file doesn't exist
function filesystem.effectivePermissions(file, user)
    expect(1, file, "string", "table")
    user = expect(2, user, "number", "nil") or util.syscall.getpid()
    if type(file) == "string" then
        file = util.syscall.stat(file)
        if not file then return nil end
    end
    expect.field(file, "permissions", "table")
    expect.field(file, "worldPermissions", "table")
    return file.permissions[user] or file.worldPermissions
end

--- A table which stores file statistics.
-- @type FileStat
local FileStat = {}
--- Stores the type of file: one of "file", "directory", "link", "special"
FileStat.type = ""
--- The size of the file
FileStat.size = 0
--- The creation date of the file, in milliseconds since January 1, 1970
FileStat.created = 0
--- The modification date of the file, in milliseconds since January 1, 1970
FileStat.modified = 0
--- The owner of the file
FileStat.owner = ""
--- The permissions of the file for each user, indexed by user name
FileStat.permissions = {
    read = false, -- Whether the file can be read
    write = false, -- Whether the file can be written to
    execute = false -- Whether the file can be executed
}
--- The permissions of the file for all users not in @{FileStat.permissions}
FileStat.worldPermissions = {
    read = false, -- Whether the file can be read
    write = false, -- Whether the file can be written to
    execute = false -- Whether the file can be executed
}
--- Any additional data from the filesystem
FileStat.special = {}

return filesystem