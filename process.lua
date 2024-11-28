--- The process module allows querying various properties about the current
-- process, as well as creating, modifying, and searching other processes.
--
-- @module system.process

local expect = require "expect"
local util = require "util"

local process = {}

--- Returns the process ID of the current process.
-- @treturn number The process ID of the current process
function process.getpid()
    return util.syscall.getpid()
end

--- Returns the process ID of the parent process, if available.
-- @treturn number The process ID of the parent process, if available
function process.getppid()
    return util.syscall.getppid()
end

--- Returns the username the process is running under.
-- @treturn string The username the process is running under
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
-- @treturn number The amount of time this process has executed
function process.clock()
    return util.syscall.clock()
end

--- Returns the environment variable table for the current process.
-- @treturn table The environment variable table for the current process
function process.getenv()
    return util.syscall.getenv()
end

--- Returns the environment table for the current process.
-- @treturn table The environment table for the current process
function process.getfenv()
    return util.syscall.getfenv()
end

--- Returns the name of the current process.
-- @treturn string The name of the current process
function process.getname()
    return util.syscall.getname()
end

--- Returns the working directory of the current process.
-- @treturn string The working directory of the current process
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
-- @treturn number The PID of the new process.
function process.fork(func, name, ...)
    expect(1, func, "function")
    expect(2, name, "string", "nil")
    return util.syscall.fork(func, name, ...)
end

--- Creates a new process running the specified function with arguments. This
-- process will be placed in the background, meaning it has no stdin/out.
-- @tparam function func The function to run in the new process. This will be the
-- main function of the first thread, and will have its environment set to the
-- new process's environment.
-- @tparam string name? The name of the new process.
-- @tparam any ... Any arguments to pass to the function.
-- @treturn number The PID of the new process.
function process.forkbg(func, name, ...)
    expect(1, func, "function")
    expect(2, name, "string", "nil")
    return util.syscall.fork(function(...)
        util.syscall.stdin()
        util.syscall.stdout()
        util.syscall.stderr()
        setfenv(func, _ENV)
        return func(...)
    end, name, ...)
end

--- Replaces the current process with the contents of the specified file.
-- This function does not return - it can only throw an error.
-- @tparam string path The path to the file to execute.
-- @tparam any ... Any arguments to pass to the file.
function process.exec(path, ...)
    expect(1, path, "string")
    return util.syscall.exec(path, ...)
end

--- Replaces the current process with the contents of the specified file or
-- command, searching the PATH environment variable if necessary.
-- This function does not return - it can only throw an error.
-- @tparam string command The command or file to execute.
-- @tparam any ... Any arguments to pass to the file.
function process.execp(command, ...)
    expect(1, command, "string")
    local path = util.syscall.getenv().PATH
    if command:find "/" or type(path) ~= "string" then return util.syscall.exec(command, ...) end
    for dir in path:gmatch "[^:]+" do
        local p = util.syscall.combine(dir, command)
        local s = util.syscall.stat(p)
        if not s then
            p = util.syscall.combine(dir, command .. ".lua")
            s = util.syscall.stat(p)
        end
        if s and s.type ~= "directory" then return util.syscall.exec(p, ...) end
    end
    error(command .. ": No such file", 2)
end

--- Starts a new process from the specified path.
-- @tparam string path The path to the file to execute.
-- @tparam any ... Any arguments to pass to the file.
-- @treturn number The PID of the new process.
function process.start(path, ...)
    expect(1, path, "string")
    return util.syscall.fork(function(...) return coroutine.yield("syscall", "exec", ...) end, path, path, ...)
end

--- Starts a new process from the specified path. This process will be placed in
-- the background, meaning it has no stdin/out.
-- @tparam string path The path to the file to execute.
-- @tparam any ... Any arguments to pass to the file.
-- @treturn number The PID of the new process.
function process.startbg(path, ...)
    expect(1, path, "string")
    return util.syscall.fork(function(...)
        util.syscall.stdin()
        util.syscall.stdout()
        util.syscall.stderr()
        return coroutine.yield("syscall", "exec", ...)
    end, path, path, ...)
end

--- Runs a program from the specified path in a new process, waiting until it completes.
-- @tparam string path The command or file to execute
-- @tparam any ... Any arguments to pass to the file
-- @treturn[1] true When the process succeeded
-- @treturn[1] any The return value from the process
-- @treturn[2] false When the process errored
-- @treturn[2] string The error message from the process
function process.run(command, ...)
    expect(1, command, "string")
    local PATH = util.syscall.getenv().PATH
    local path
    if command:find "/" or type(PATH) ~= "string" then path = command else
        for dir in PATH:gmatch "[^:]+" do
            local p = util.syscall.combine(dir, command)
            local s = util.syscall.stat(p)
            if not s then
                p = util.syscall.combine(dir, command .. ".lua")
                s = util.syscall.stat(p)
            end
            if s and s.type ~= "directory" then path = p break end
        end
        error(command .. ": No such file", 2)
    end
    local pid = util.syscall.fork(function(...) return coroutine.yield("syscall", "exec", ...) end, path, path, ...)
    local event, param
    repeat event, param = coroutine.yield() until event == "process_complete" and param.id == pid
    return param.error == nil, param.error or param.value
end

--- Creates a new thread running the specified function with arguments.
-- Threads in the same process share the same environment, event queue, and
-- other properties.
-- @tparam function func The function to start
-- @tparam any ... Any arguments to pass to the function
-- @treturn number The ID of the new thread
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

--- Runs a function when the program exists. This function will never get any
-- events, and is time-limited to 100 syscalls due to running in a different
-- context than normal threads - avoid passing long-running functions.
-- Functions added here cannot be removed later, so if the function may not be
-- needed after being added, use a variable check to disable it instead.
-- @tparam function fn The function to call at exit
function process.atexit(fn)
    expect(1, fn, "function")
    return util.syscall.atexit(fn)
end

--- Returns a list of all valid PIDs.
-- @treturn table A list of all valid PIDs
function process.getplist()
    return util.syscall.getplist()
end

--- Returns a table with various information about the specified process.
-- @tparam number pid The process ID to query.
-- @treturn {id=number,name=string,user=string,parent?=number,dir=string,stdin?=number,stdout?=number,stderr?=number,cputime=number,systime=number,threads={[number]={id=number,name=string,status=string}}}|nil The process information, or nil if the process doesn't exist.
function process.getpinfo(pid)
    expect(1, pid, "number")
    return util.syscall.getpinfo(pid)
end

--- Sets the niceness level of the specified process, or the current one if left
-- unspecified. Nice values cause the process to run longer with a lower number
-- (requires root), or shorter with a higher number. Values range from -20 to 20.
-- @tparam number level The nice level to set to
-- @tparam[opt] number pid The process ID to modify (must be root or same user)
function process.nice(level, pid)
    expect(1, level, "number")
    expect.range(level, -20, 20)
    expect(2, pid, "number", "nil")
    return util.syscall.nice(level, pid)
end

--- Debugging subsystem
-- @section system.process.debug
process.debug = {}

function process.debug.enable(pid, enabled)
    expect(1, pid, "number", "nil")
    expect(2, enabled, "boolean")
    return util.syscall.debug_enable(pid, enabled)
end

function process.debug.brk(pid, thread)
    expect(1, pid, "number", "nil")
    expect(2, thread, "number", "nil")
    return util.syscall.debug_break(pid, thread)
end

function process.debug.continue(pid, thread)
    expect(1, pid, "number")
    expect(2, thread, "number", "nil")
    return util.syscall.debug_continue(pid, thread)
end

function process.debug.setbreakpoint(pid, thread, type, filter)
    expect(1, pid, "number")
    expect(2, thread, "number", "nil")
    expect(3, type, "string", "number")
    expect(4, filter, "table", "nil")
    return util.syscall.debug_setbreakpoint(pid, thread, type, filter)
end

function process.debug.unsetbreakpoint(pid, breakpoint)
    expect(1, pid, "number")
    expect(2, breakpoint, "number")
    return util.syscall.debug_unsetbreakpoint(pid, breakpoint)
end

function process.debug.listbreakpoints(pid)
    expect(1, pid, "number")
    return util.syscall.debug_listbreakpoints(pid)
end

function process.debug.getinfo(pid, thread, level, what)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, what, "string", "nil")
    return util.syscall.debug_getinfo(pid, thread, level, what)
end

function process.debug.getlocal(pid, thread, level, n)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, n, "number")
    return util.syscall.debug_getlocal(pid, thread, level, n)
end

function process.debug.getupvalue(pid, thread, level, n)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, n, "number")
    return util.syscall.debug_getupvalue(pid, thread, level, n)
end

function process.debug.exec(pid, thread, fn)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, fn, "function")
    return util.syscall.debug_exec(pid, thread, fn)
end

return process