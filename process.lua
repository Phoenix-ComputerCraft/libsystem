--- The process module allows querying various properties about the current
-- process, as well as creating, modifying, and searching other processes.
--
-- @module system.process

local expect = require "expect"
local util = require "util"

local process = {}

--- Returns the process ID of the current process.
function process.getpid()
    return util.syscall.getpid()
end

--- Returns the process ID of the parent process, if available.
function process.getppid()
    return util.syscall.getppid()
end

--- Returns the username the process is running under.
function process.getuser()
    return util.syscall.getuser()
end

--- Sets the user of the current process. This can only be run by root.
-- @tparam string user The user to switch to
function process.setuser(user)
    expect(1, user, "string")
    return util.syscall.setuser(user)
end

--- Returns the amount of time this process has executed. This may not be
-- entirely accurate due to a lack of precision in the system clock.
function process.clock()
    return util.syscall.clock()
end

--- Returns the environment table for the current process.
function process.getenv()
    return util.syscall.getenv()
end

--- Returns the name of the current process.
function process.getname()
    return util.syscall.getname()
end

--- Returns the working directory of the current process.
function process.getcwd()
    return util.syscall.getcwd()
end

--- Sets the working directory of the current process.
-- @tparam string dir The new working directory, which must be absolute and existent.
function process.chdir(dir)
    expect(1, dir, "string")
    return util.syscall.chdir(dir)
end

--- Creates a new process running the specified function with arguments.
-- @tparam function func The function to run in the new process. This will be the
-- main function of the first thread, and will have its environment set to the
-- new process's environment.
-- @tparam string name? The name of the new process.
-- @tparam any ... Any arguments to pass to the function.
-- @treturn The PID of the new process.
function process.fork(func, name, ...)
    expect(1, func, "function")
    expect(2, name, "string", "nil")
    return util.syscall.fork(func, name, ...)
end

--- Replaces the current process with the contents of the specified file.
-- This function does not return - it can only throw an error.
-- @tparam string path The path to the file to execute.
-- @tparam any ... Any arguments to pass to the file.
function process.exec(path, ...)
    expect(1, path, "string")
    return util.syscall.exec(path, ...)
end

--- Starts a new process from the specified path.
-- @tparam string path The path to the file to execute.
-- @tparam any ... Any arguments to pass to the file.
-- @treturn number The PID of the new process.
function process.start(path, ...)
    expect(1, path, "string")
    return util.syscall.fork(function(...) return coroutine.yield("syscall", "exec", ...) end, path, path, ...)
end

--- Creates a new thread running the specified function with arguments.
-- Threads in the same process share the same environment, event queue, and
-- other properties.
function process.newthread(func, ...)
    expect(1, func, "function")
    return util.syscall.newthread(func, ...)
end

--- Ends the current process immediately, stopping all threads and sending the
-- specified return value to the parent. This function does not return.
-- @tparam number code? The value to return.
function process.exit(code)
    return util.syscall.exit(code)
end

--- Returns a list of all valid PIDs.
function process.getplist()
    return util.syscall.getplist()
end

--- Returns a table with various information about the specified process.
-- @tparam number pid The process ID to query.
-- @treturn { id = number, name = string, user = string, parent? = number, dir = string, stdin? = number, stdout? = number, stderr? = number, cputime = number, systime = number, threads = { [number] = { id = number, name = string, status = string } } }|nil The process information, or nil if the process doesn't exist.
function process.getpinfo(pid)
    expect(1, pid, "number")
    return util.syscall.getpinfo(pid)
end

return process