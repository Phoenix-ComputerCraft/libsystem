local expect = require "expect"
local util = require "util"

--- The sync library exposes interfaces for various synchronization structures.
---
--- !doctype module
--- @class system.sync
local sync = {}

--#region Mutex

--- A mutex is an object that controls access to a variable across multiple threads.
--- It ensures only one thread accesses a resource at a time by blocking other
--- threads from locking the mutex until the current thread unlocks it.
--- !doctype class
--- @class system.sync.mutex
sync.mutex = {}

--- Creates a new mutex.
--- @param recursive? boolean Whether to make the mutex recursive
--- @return system.sync.mutex result The new mutex object
function sync.mutex.new(recursive)
    expect(1, recursive, "boolean", "nil")
    return setmetatable({recursive = recursive and 0}, {__name = "mutex", __index = sync.mutex})
end

--- Locks the mutex, waiting if it's currently owned by another thread.
function sync.mutex:lock()
    expect(1, self, "mutex")
    return util.syscall.lockmutex(self)
end

--- Unlocks the mutex. This is only valid from the thread that owns the lock.
function sync.mutex:unlock()
    expect(1, self, "mutex")
    return util.syscall.unlockmutex(self)
end

--- Tries to lock the thread, returning false if it could not be locked.
--- @return boolean result Whether the mutex is now locked
function sync.mutex:tryLock()
    expect(1, self, "mutex")
    return util.syscall.trylockmutex(self)
end

--- Locks the mutex, waiting until it's unlocked or until the specified timeout.
--- @param timeout number The number of seconds to wait
--- @return boolean result Whether the mutex is now locked
function sync.mutex:tryLockFor(timeout)
    expect(1, self, "mutex")
    expect(2, timeout, "number")
    return util.syscall.timelockmutex(self, timeout)
end

--#endregion
--#region Semaphore

--- A semaphore controls access to a limited number of resources. A function may
--- acquire a resource from the semaphore, decrementing its available count. If
--- the count is zero, it waits until another function releases a resource, at
--- which point it will acquire it and return.
--- !doctype class
--- @class system.sync.semaphore
sync.semaphore = {}

--- Creates a new semaphore.
--- @param init? number The initial count of the semaphore (defaults to 1)
--- @return system.sync.semaphore result The new semaphore object
function sync.semaphore.new(init)
    expect(1, init, "number", "nil")
    if init then expect.range(init, 0) end
    return setmetatable({count = init or 1}, {__name = "semaphore", __index = sync.semaphore})
end

--- Acquires a resource from the semaphore, waiting until there is one available.
function sync.semaphore:acquire()
    expect(1, self, "semaphore")
    return util.syscall.acquiresemaphore(self)
end

--- Acquires a resource from the semaphore, waiting until there is one available or until a timeout.
--- @param timeout number The number of seconds to wait
--- @return boolean result Whether the resource was acquired
function sync.semaphore:tryAcquireFor(timeout)
    expect(1, self, "semaphore")
    expect(2, timeout, "number")
    return util.syscall.timeacquiresemaphore(self, timeout)
end

--- Releases a resource to the semaphore. This can be called from any thread.
function sync.semaphore:release()
    expect(1, self, "semaphore")
    return util.syscall.releasesemaphore(self)
end

--#endregion
--#region Condition variable

--- A condition variable allows threads to wait until another thread notifies
--- them to resume.
--- !doctype class
--- @class system.sync.conditionVariable
sync.conditionVariable = {}

--- Creates a new condition variable.
--- @return system.sync.conditionVariable result The new condition variable.
function sync.conditionVariable.new()
    return setmetatable({
        lock = sync.mutex.new(),
        sem = sync.semaphore.new(0),
        waiting = 0
    }, {__name = "condition variable", __index = sync.conditionVariable})
end

--- Waits for a notification from another thread.
function sync.conditionVariable:wait()
    expect(1, self, "condition variable")
    self.lock:lock()
    self.waiting = self.waiting + 1
    self.lock:unlock()
    self.sem:acquire()
    self.lock:lock()
    self.waiting = self.waiting - 1
    self.lock:unlock()
end

--- Waits for a notification from another thread, or until a timeout occurs.
--- @param timeout number The number of seconds to wait
--- @return boolean result Whether a notification occurred
function sync.conditionVariable:waitFor(timeout)
    expect(1, self, "condition variable")
    expect(2, timeout, "number")
    self.lock:lock()
    self.waiting = self.waiting + 1
    self.lock:unlock()
    local retval = self.sem:tryAcquireFor(timeout)
    self.lock:lock()
    self.waiting = self.waiting - 1
    self.lock:unlock()
    return retval
end

--- Notifies a single (unspecified) thread to continue.
function sync.conditionVariable:notifyOne()
    expect(1, self, "condition variable")
    self.sem:release()
end

--- Notifies all waiting threads to continue.
function sync.conditionVariable:notifyAll()
    expect(1, self, "condition variable")
    self.lock:lock()
    self.sem.count = self.sem.count + self.waiting - 1
    self.sem:release()
    self.lock:unlock()
end

--#endregion
--#region Atomic variables

--- TODO

--#endregion
--#region Barrier

--- A barrier is a lock that waits for a specific number of threads to wait on
--- the object, at which point all threads will be released together.
--- !doctype class
--- @class system.sync.barrier
sync.barrier = {}

--- Creates a new barrier object.
--- @param count number The number of threads to wait for
--- @return system.sync.barrier result A new barrier object
function sync.barrier.new(count)
    expect(1, count, "number")
    expect.range(count, 1)
    return setmetatable({
        cvar = sync.conditionVariable.new(),
        lock = sync.mutex.new(),
        left = count,
        count = count,
        cycles = 0
    }, {__name = "barrier", __index = sync.barrier})
end

--- Adds one to the thread wait count, and waits until it meets the limit.
--- @return boolean result Whether this call directly resulted in the barrier being met
function sync.barrier:wait()
    expect(1, self, "barrier")
    self.lock:lock()
    self.left = self.left - 1
    if self.left == 0 then
        self.left = self.count
        self.cycles = self.cycles + 1
        self.lock:unlock()
        self.cvar:notifyAll()
        return true
    else
        self.lock:unlock()
        self.cvar:wait()
        return false
    end
end

--#endregion
--#region Readers-writer lock

--- A readers-writer lock implements two related locks: a read lock, which can
--- be held by multiple threads, and a write lock, which can only be held by one
--- thread. Multiple threads can hold a read lock, but a write lock blocks both
--- read and write locks.
--- !doctype class
--- @class system.sync.rwLock
sync.rwLock = {}

--- Creates a new RW lock.
--- @return system.sync.rwLock result The new RW lock
function sync.rwLock.new()
    return setmetatable({
        count = 0,
        readLock = sync.mutex.new(),
        globalLock = sync.semaphore.new(1)
    }, {__name = "rwlock", __index = sync.rwLock})
end

--- Acquires the lock for reading, waiting for the write lock to be released first.
function sync.rwLock:lockRead()
    expect(1, self, "rwlock")
    self.readLock:lock()
    self.count = self.count + 1
    if self.count == 1 then self.globalLock:acquire() end
    self.readLock:unlock()
end

--- Releases the lock for reading.
function sync.rwLock:unlockRead()
    expect(1, self, "rwlock")
    self.readLock:lock()
    self.count = self.count - 1
    if self.count == 0 then self.globalLock:release() end
    self.readLock:unlock()
end

--- Acquires the lock for writing, waiting for the read and write locks to be released.
function sync.rwLock:lockWrite()
    expect(1, self, "rwlock")
    self.globalLock:acquire()
end

--- Releases the lock for writing.
function sync.rwLock:unlockWrite()
    expect(1, self, "rwlock")
    self.globalLock:release()
end

--#endregion

--- Calls a function, ensuring that the mutex is locked before calling and unlocked
--- after calling, even if the function returns early or throws an error.
--- @param mutex system.sync.mutex The mutex to lock
--- @param fn function The function to call
--- @param ... any Any parameters to pass
--- @return any ... The return values from the function
function sync.lockGuard(mutex, fn, ...)
    expect(1, mutex, "mutex")
    expect(2, fn, "function")
    mutex:lock()
    local res = table.pack(pcall(fn, ...))
    mutex:unlock()
    if not res[1] then error(res[2], 0) end
    return table.unpack(res, 2, res.n)
end

--- Creates a new synchronized table. A synchronized table is a table that's
--- protected by a mutex. The table can only be accessed by calling it as a
--- function, which will lock the mutex and calls the callback with the table.
--- @return fun(callback:fun(any):any) result The accessor for the variable
function sync.synctab()
    local tab = {}
    local lock = sync.mutex.new()
    return function(fn)
        expect(1, fn, "function")
        return sync.lockGuard(lock, fn, tab)
    end
end

return sync
