local expect = require "expect"
local util = require "util"

--- The process module allows querying various properties about the current
--- process, as well as creating, modifying, and searching other processes.
---
--- !doctype module
--- @class system.process
local process = {}

--- Returns the process ID of the current process.
--- @return number result The process ID of the current process
function process.getpid()
    return util.syscall.getpid()
end

--- Returns the process ID of the parent process, if available.
--- @return number result The process ID of the parent process, if available
function process.getppid()
    return util.syscall.getppid()
end

--- Returns the username the process is running under.
--- @return string result The username the process is running under
function process.getuser()
    return util.syscall.getuser()
end

--- Sets the user of the current process. This can only be run by root.
--- @param user string The user to switch to
function process.setuser(user)
    expect(1, user, "string")
    return util.syscall.setuser(user)
end

--- Returns the amount of time this process has executed.
--- 
--- This may not be
--- entirely accurate due to a lack of precision in the system clock.
--- @return number result The amount of time this process has executed
function process.clock()
    return util.syscall.clock()
end

--- Returns the environment variable table for the current process.
--- @return table result The environment variable table for the current process
function process.getenv()
    return util.syscall.getenv()
end

--- Returns the environment table for the current process.
--- @return table result The environment table for the current process
function process.getfenv()
    return util.syscall.getfenv()
end

--- Returns the name of the current process.
--- @return string result The name of the current process
function process.getname()
    return util.syscall.getname()
end

--- Returns the working directory of the current process.
--- @return string result The working directory of the current process
function process.getcwd()
    return util.syscall.getcwd()
end

--- Sets the working directory of the current process.
--- @param dir string The new working directory, which must be absolute and existent.
function process.chdir(dir)
    expect(1, dir, "string")
    return util.syscall.chdir(dir)
end

--- Creates a new process running the specified function with arguments.
--- @param func function The function to run in the new process. This will be the
--- main function of the first thread, and will have its environment set to the
--- new process's environment.
--- @param name? string The name of the new process.
--- @param ... any Any arguments to pass to the function.
--- @return number result The PID of the new process.
function process.fork(func, name, ...)
    expect(1, func, "function")
    expect(2, name, "string", "nil")
    return util.syscall.fork(func, name, ...)
end

--- Creates a new process running the specified function with arguments. This
--- process will be placed in the background, meaning it has no stdin/out.
--- @param func function The function to run in the new process. This will be the
--- main function of the first thread, and will have its environment set to the
--- new process's environment.
--- @param name? string The name of the new process.
--- @param ... any Any arguments to pass to the function.
--- @return number result The PID of the new process.
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
--- 
--- This function does not return - it can only throw an error.
--- @param path string The path to the file to execute.
--- @param ... any Any arguments to pass to the file.
function process.exec(path, ...)
    expect(1, path, "string")
    return util.syscall.exec(path, ...)
end

--- Replaces the current process with the contents of the specified file or
--- command, searching the PATH environment variable if necessary.
--- 
--- This function does not return - it can only throw an error.
--- @param command string The command or file to execute.
--- @param ... any Any arguments to pass to the file.
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
--- @param path string The path to the file to execute.
--- @param ... any Any arguments to pass to the file.
--- @return number result The PID of the new process.
function process.start(path, ...)
    expect(1, path, "string")
    return util.syscall.fork(function(...) return coroutine.yield("syscall", "exec", ...) end, path, path, ...)
end

--- Starts a new process from the specified path. This process will be placed in
--- the background, meaning it has no stdin/out.
--- @param path string The path to the file to execute.
--- @param ... any Any arguments to pass to the file.
--- @return number result The PID of the new process.
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
--- @param command string The command or file to execute
--- @param ... any Any arguments to pass to the file
--- @return boolean ok Whether the process succeeded
--- @return any|string res The return value from the process, or an error
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
--- 
--- Threads in the same process share the same environment, event queue, and
--- other properties.
--- @param func function The function to start
--- @param ... any Any arguments to pass to the function
--- @return number result The ID of the new thread
function process.newthread(func, ...)
    expect(1, func, "function")
    return util.syscall.newthread(func, ...)
end

--- Ends the current process immediately, stopping all threads and sending the
--- specified return value to the parent.
--- 
--- This function does not return.
--- @param code? number The value to return.
function process.exit(code)
    return util.syscall.exit(code)
end

--- Runs a function when the program exists.
--- 
--- This function will never get any
--- events, and is time-limited to 100 syscalls due to running in a different
--- context than normal threads - avoid passing long-running functions.
--- Functions added here cannot be removed later, so if the function may not be
--- needed after being added, use a variable check to disable it instead.
--- @param fn function The function to call at exit
function process.atexit(fn)
    expect(1, fn, "function")
    return util.syscall.atexit(fn)
end

--- Returns a list of all valid PIDs.
--- @return table result A list of all valid PIDs
function process.getplist()
    return util.syscall.getplist()
end

--- Returns a table with various information about the specified process.
--- @param pid number The process ID to query.
--- @return {id:number,name:string,user:string,parent?:number,dir:string,stdin?:number,stdout?:number,stderr?:number,cputime:number,systime:number,threads:{[number]:{id:number,name:string,status:string}}}|nil result The process information, or nil if the process doesn't exist.
function process.getpinfo(pid)
    expect(1, pid, "number")
    return util.syscall.getpinfo(pid)
end

--- Sets the niceness level of the specified process, or the current one if left
--- unspecified.
--- 
--- Nice values cause the process to run longer with a lower number
--- (requires root), or shorter with a higher number. Values range from -20 to 20.
--- @param level number The nice level to set to
--- @param pid? number The process ID to modify (must be root or same user)
function process.nice(level, pid)
    expect(1, level, "number")
    expect.range(level, -20, 20)
    expect(2, pid, "number", "nil")
    return util.syscall.nice(level, pid)
end

--- Releases a process to be accepted by another process.
--- 
--- This sets up a change
--- in process parent - the designated new parent will be able to accept the
--- process after releasing, which will cause all child-related events (such as
--- `process_complete`) to be sent to the new parent.
--- 
--- This function does not change the parent immediately - the new parent has to
--- accept the transfer after releasing.
--- @param pid number The ID of the process to release, which must be a child of this process
--- @param newparent number The process ID which may accept this process as a child
function process.releasechild(pid, newparent)
    expect(1, pid, "number")
    expect(2, newparent, "number")
    return util.syscall.releasechild(pid, newparent)
end

--- Accepts a new child process which was previously released to this one.
--- 
--- This changes the process's parent after calling.
--- Process events such as `process_complete` will now be sent to the current
--- process instead of the former parent.
--- @param pid number The ID of the process to accept, which must have previously
--- been released to this process by its old parent
--- @param takestdio? boolean If set, the child process will take the stdio handles of the current process
function process.acceptchild(pid, takestdio)
    expect(1, pid, "number")
    expect(2, takestdio, "boolean", "nil")
    return util.syscall.acceptchild(pid, takestdio)
end

--- Debugging subsystem
--- @section system.process.debug
process.debug = {}

--- Enables or disables debugging for the specified process.
--- 
--- If `pid` is `nil`,
--- it will set whether other processes can debug this one. In other words,
--- calling `debug_enable(nil, false)` will disable any form of debugging on the
--- current program, even by root.
--- @param pid number The process ID to operate on (`nil` for this process)
--- @param enabled boolean Whether to enable debugging
function process.debug.enable(pid, enabled)
    expect(1, pid, "number", "nil")
    expect(2, enabled, "boolean")
    return util.syscall.debug_enable(pid, enabled)
end

--- Pauses the specified thread, or all threads if none is specified, in the
--- target process.
--- 
--- This will trigger a `debug_break` event in the calling
--- process for each thread that was paused as a result of this syscall.
---
--- If `pid` is `nil`, then this syscall operates differently: it will pause the
--- current thread (regardless of the `thread` parameter), and sends a
--- `debug_break` event to the last process that called `debug_enable` on this
--- process. If debugging is not enabled, then this syscall is a no-op, allowing
--- for programs to break to a debugger only if one is enabled.
--- @param pid number The process ID to pause, or `nil` to pause the current process
--- @param thread number The thread to pause, or `nil` to pause all threads
function process.debug.brk(pid, thread)
    expect(1, pid, "number", "nil")
    expect(2, thread, "number", "nil")
    return util.syscall.debug_break(pid, thread)
end

--- Continues a paused thread, or all threads if none is specified.
--- @param pid number The process ID to unpause
--- @param thread number The thread to unpause, or `nil` to unpause all threads
function process.debug.continue(pid, thread)
    expect(1, pid, "number")
    expect(2, thread, "number", "nil")
    return util.syscall.debug_continue(pid, thread)
end

--- Sets a breakpoint for the specified process, optionally filtering by thread.
--- 
--- When a breakpoint is hit in the target process, the thread (or all threads if
--- none is specified) is paused, and a `debug_break` event is queued in the
--- process that set the breakpoint.
---
--- The type can be one of these values:
--- - `call`: Break on a function call
--- - `return`: Break on a function return
--- - `line`: Break when execution changes lines
--- - `error`: Break when an error is thrown
--- - `resume`: Break when a coroutine is resumed
--- - `yield`: Break when a coroutine yields (not including preemption)
--- - `syscall`: Break when the process executes a system call
---  - For this case, the filter argument will only respect the `name` field
---    (for syscall name)
--- - Any number: Break after this number of VM instructions
---
--- The filter contains entries from a `debug.getinfo` table to match before
--- breaking. The breakpoint will only be triggered if all provided filters match.
--- @usage This example shows how to set a breakpoint on a specific line of a file, and then wait for the breakpoint to be hit:
--- ```lua
---    local bp = syscall.debug_setbreakpoint(processID, nil, "line", {
---        source = "@/home/user/program.lua",
---        currentline = 11
---    })
---    repeat
---        local event, param = coroutine.yield()
---    until event == "debug_break" and param.breakpoint == bp
--- ```
--- @param pid number The process ID to set the breakpoint on
--- @param thread number The thread to set the breakpoint on (or `nil` for any thread)
--- @param type string|number The type of breakpoint to set
--- @param filter? table A filter to set on the breakpoint (see above)
--- @return number result The ID of the new breakpoint
function process.debug.setbreakpoint(pid, thread, type, filter)
    expect(1, pid, "number")
    expect(2, thread, "number", "nil")
    expect(3, type, "string", "number")
    expect(4, filter, "table", "nil")
    return util.syscall.debug_setbreakpoint(pid, thread, type, filter)
end

--- Unsets a previously set breakpoint.
--- @param pid number The process ID to operate on
--- @param breakpoint number The ID of the breakpoint to remove
function process.debug.unsetbreakpoint(pid, breakpoint)
    expect(1, pid, "number")
    expect(2, breakpoint, "number")
    return util.syscall.debug_unsetbreakpoint(pid, breakpoint)
end

--- Returns a list of currently set breakpoints.
--- 
--- Each entry has a `type` field,
--- as well as an optional `thread` field, and any filter items passed to
--- `debug_setbreakpoint`.
--- @param pid number The process ID to check
--- @return table[] result A list of currently set breakpoints. This table may have holes in it if some breakpoints were unset!
function process.debug.listbreakpoints(pid)
    expect(1, pid, "number")
    return util.syscall.debug_listbreakpoints(pid)
end

--- Calls `debug.getinfo` on the specified thread in another process.
--- 
--- Debugging
--- must be enabled for the target process, and the target thread must be paused.
--- @param pid number The process ID to operate on
--- @param thread number The thread ID to operate on
--- @param level number The level in the call stack to get info for
--- @param what? string A string with the info to extract, or `nil` for all
--- @return table result A table from `debug.getinfo`
function process.debug.getinfo(pid, thread, level, what)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, what, "string", "nil")
    return util.syscall.debug_getinfo(pid, thread, level, what)
end

--- Calls `debug.getlocal` on the specified thread in another process.
--- 
--- Debugging
--- must be enabled for the target process, and the target thread must be paused.
--- @param pid number The process ID to operate on
--- @param thread number The thread ID to operate on
--- @param level number The level in the call stack to get info for
--- @param n number The index of the local to check
--- @return string|nil result The local name
--- @return any result The local value
function process.debug.getlocal(pid, thread, level, n)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, n, "number")
    return util.syscall.debug_getlocal(pid, thread, level, n)
end

--- Calls `debug.getupvalue` on the specified thread in another process.
--- 
--- Debugging
--- must be enabled for the target process, and the target thread must be paused.
--- @param pid number The process ID to operate on
--- @param thread number The thread ID to operate on
--- @param level number The level in the call stack to get info for
--- @param n number The index of the upvalue to check
--- @return string|nil result The upvalue name
--- @return any result The upvalue value
function process.debug.getupvalue(pid, thread, level, n)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, level, "number")
    expect(4, n, "number")
    return util.syscall.debug_getupvalue(pid, thread, level, n)
end

--- Executes a function in the context of another process/thread.
--- 
--- Debugging must
--- be enabled for the target process, and the target thread must be paused. The
--- environment for the function will be set to the environment of the process.
--- Note that the function runs under the hook environment, and thus will not be
--- preempted - avoid long-running tasks in this environment. (This may be fixed
--- in the future!)
--- @param pid number The process ID to operate on
--- @param thread number The thread ID to operate on
--- @param fn function The function to call
--- @return any ... The values returned from the function
function process.debug.exec(pid, thread, fn)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, fn, "function")
    util.syscall.debug_exec(pid, thread, fn)
    while true do
        local event, param = coroutine.yield()
        if event == "debug_exec_result" and param.process == pid and param.thread == thread then
            if param.ok then return table.unpack(param, 1, param.n)
            else error(param.error, 0) end
        end
    end
end

--- Executes a function in the context of another process/thread asynchronously.
--- 
--- Debugging must be enabled for the target process, and the target thread must
--- be paused. The environment for the function will be set to the environment of
--- the process. The result of the function call will be passed in a
--- `debug_exec_result` event. Note that the function runs under the hook
--- environment, and thus will not be preempted - avoid long-running tasks in
--- this environment. (This may be fixed in the future!)
--- @param pid number The process ID to operate on
--- @param thread number The thread ID to operate on
--- @param fn function The function to call
function process.debug.execAsync(pid, thread, fn)
    expect(1, pid, "number")
    expect(2, thread, "number")
    expect(3, fn, "function")
    return util.syscall.debug_exec(pid, thread, fn)
end

return process