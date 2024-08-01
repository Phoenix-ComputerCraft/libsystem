--- The terminal module defines functions to allow interacting with the terminal
-- and screen, as well as handling user input.
--
-- @module system.terminal

local expect = require "expect"
local keys = require "keys"
local util = require "util"

local terminal = {}

--- Constants for colors. This includes both normal and British spelling.
terminal.colors = {
    white = 0,
    orange = 1,
    magenta = 2,
    lightBlue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    grey = 7,
    lightGray = 8,
    lightGrey = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15
}
terminal.colours = terminal.colors

--- Converts a @{terminal.colors} constant to an ANSI escape code.
-- @tparam number color The color to convert
-- @tparam[opt=false] boolean background Whether the escape should set the background
-- @treturn string The escape code generated for the color
function terminal.toEscape(color, background)
    expect(1, color, "number")
    expect(2, background, "boolean", "nil")
    expect.range(color, 0, 15)
    local n = 37 - (color % 8)
    if color < 8 then n = n + 60 end
    if background then n = n + 10 end
    return "\x1b[" .. n .. "m"
end

--- Writes text to the standard output stream.
-- @param ... The entries to write. Each one will be separated by tabs (`\t`).
function terminal.write(...)
    return util.syscall.write(...)
end

--- Writes text to the standard error stream.
-- @param ... The entries to write. Each one will be separated by tabs (`\t`).
function terminal.writeerr(...)
    return util.syscall.writeerr(...)
end

--- Reads a number of characters from the standard input stream.
-- @tparam number n The number of characters to read
-- @treturn string|nil The text read, or nil if EOF was reached.
function terminal.read(n)
    expect(1, n, "number")
    return util.syscall.read(n)
end

--- Reads a single line of text from the standard input stream.
-- @treturn string|nil The text read, or nil if EOF was reached.
function terminal.readline()
    return util.syscall.readline()
end

--- Reads a line of text from the standard input stream, allowing history and
-- autocompletion.
-- @tparam[opt] table history A list of history items to scroll through with the
-- arrow keys, with the first index being the most recent
-- @tparam[opt] function(partial:string):string[] completion A function to use
-- to get completion options
-- @treturn string|nil The text read, or nil if EOF was reached.
function terminal.readline2(history, completion)
    expect(1, history, "table", "nil")
    expect(2, completion, "function", "nil")

    local line = ""
    local cursorPos = 1
    local historyPos = 0
    local history0
    local completionTable, completionPos

    terminal.termctl{echo = false}
    while true do
        local event, param = coroutine.yield()
        if event == "char" then
            if completionTable and completionTable[completionPos] and param.character == completionTable[completionPos]:sub(-1) then
                completionTable = nil
            else
                completionTable = nil
                if cursorPos <= #line then
                    terminal.write("\x1b[@" .. param.character)
                    line = line:sub(1, cursorPos - 1) .. param.character .. line:sub(cursorPos)
                else
                    terminal.write(param.character)
                    line = line .. param.character
                end
                cursorPos = cursorPos + 1
            end
        elseif event == "key" then
            if param.keycode == keys.enter then
                terminal.termctl{echo = true}
                if cursorPos <= #line then terminal.write("\x1b[" .. (#line - cursorPos + 1) .. "C") end
                terminal.write("\n")
                terminal.readline() -- clear buffer
                return line
            elseif param.keycode == keys.d and param.ctrlHeld and not param.altHeld and not param.shiftHeld then
                terminal.termctl{echo = true}
                return terminal.readline() -- clear buffer and return EOF
            elseif param.keycode == keys.backspace and cursorPos > 1 then
                completionTable = nil
                terminal.write("\x1b[D\x1b[P")
                line = line:sub(1, cursorPos - 2) .. line:sub(cursorPos)
                cursorPos = cursorPos - 1
            elseif param.keycode == keys.delete and cursorPos <= #line then
                completionTable = nil
                terminal.write("\x1b[P")
                line = line:sub(1, cursorPos - 1) .. line:sub(cursorPos + 1)
            elseif param.keycode == keys.left and cursorPos > 1 then
                completionTable = nil
                terminal.write("\x1b[D")
                cursorPos = cursorPos - 1
            elseif param.keycode == keys.right and cursorPos <= #line then
                completionTable = nil
                terminal.write("\x1b[C")
                cursorPos = cursorPos + 1
            elseif param.keycode == keys.up and history and historyPos < #history then
                completionTable = nil
                if cursorPos > 1 then terminal.write("\x1b[" .. (cursorPos - 1) .. "D") end
                terminal.write("\x1b[" .. #line .. "P")
                if historyPos == 0 then history0 = line end
                historyPos = historyPos + 1
                line = history[historyPos]
                terminal.write(line)
                cursorPos = #line + 1
            elseif param.keycode == keys.down and history and historyPos > 0 then
                completionTable = nil
                if cursorPos > 1 then terminal.write("\x1b[" .. (cursorPos - 1) .. "D") end
                terminal.write("\x1b[" .. #line .. "P")
                historyPos = historyPos - 1
                if historyPos == 0 then line = history0
                else line = history[historyPos] end
                terminal.write(line)
                cursorPos = #line + 1
            elseif param.keycode == keys.tab and completion then
                if completionTable and #completionTable > 0 then
                    terminal.write("\x1b[" .. #completionTable[completionPos] .. "D\x1b[" .. #completionTable[completionPos] .. "P")
                    line = line:sub(1, cursorPos - #completionTable[completionPos] - 1) .. line:sub(cursorPos)
                    cursorPos = cursorPos - #completionTable[completionPos]
                    completionPos = completionPos % #completionTable + 1
                else
                    completionTable = completion(line:sub(1, cursorPos - 1))
                    completionPos = 1
                end
                if completionTable[completionPos] then
                    terminal.write("\x1b[" .. #completionTable[completionPos] .. "@" .. completionTable[completionPos])
                    line = line:sub(1, cursorPos - 1) .. completionTable[completionPos] .. line:sub(cursorPos)
                    cursorPos = cursorPos + #completionTable[completionPos]
                end
            end
        elseif event == "paste" then
            completionTable = nil
            if cursorPos <= #line then
                terminal.write("\x1b[" .. #param.text .. "@" .. param.text)
                line = line:sub(1, cursorPos - 1) .. param.text .. line:sub(cursorPos)
                cursorPos = cursorPos + #param.text
            else
                terminal.write(param.text)
                line = line .. param.text
            end
            cursorPos = cursorPos + #param.text
        end
    end
end

--- Sets certain terminal control flags on the current TTY if available.
-- @tparam {cbreak?=boolean,delay?=boolean,echo?=boolean,keypad?=boolean,nlcr?=boolean,raw?=boolean} flags? The flags to set, or nil to just query.
-- @treturn {cbreak=boolean,delay=boolean,echo=boolean,keypad=boolean,nlcr=boolean,raw=boolean}|nil The flags that are currently set on the TTY, or nil if no TTY is available.
function terminal.termctl(flags)
    expect(1, flags, "table", "nil")
    if flags then
        expect.field(flags, "cbreak", "boolean", "nil")
        expect.field(flags, "delay", "boolean", "nil")
        expect.field(flags, "echo", "boolean", "nil")
        expect.field(flags, "keypad", "boolean", "nil")
        expect.field(flags, "nlcr", "boolean", "nil")
        expect.field(flags, "raw", "boolean", "nil")
    end
    return util.syscall.termctl(flags)
end

--- Opens the current output TTY in exclusive text mode, allowing direct
-- manipulation of the screen buffer. Only one process may open the terminal at
-- a time. Once opened, the screen will be cleared, and stdout will be sent to
-- an off-screen buffer to be shown once the terminal is closed. The terminal
-- will automatically be closed on process exit.
-- @treturn[1] Terminal A terminal object for the current TTY.
-- @treturn[2] nil If the terminal could not be opened.
-- @treturn[2] string An error message describing why the terminal couldn't be opened.
function terminal.openterm()
    return util.syscall.openterm()
end

--- Opens the current output TTY in exclusive graphics mode, allowing direct
-- manipulation of the pixels if available. Only one process may open the terminal
-- at a time. Once opened, the screen will be cleared, and stdout will be sent to
-- an off-screen buffer to be shown once the terminal is closed. The terminal
-- will automatically be closed on process exit. This only works on CraftOS-PC.
-- @treturn[1] GFXTerminal A graphical terminal object for the current TTY.
-- @treturn[2] nil If the terminal could not be opened.
-- @treturn[2] string An error message describing why the terminal couldn't be opened.
function terminal.opengfx()
    return util.syscall.opengfx()
end

--- Creates a new virtual TTY with the specified size. This can later be used in
-- a call to stdin/stdout/stderr.
-- @tparam number width The width of the new TTY.
-- @tparam number height The height of the new TTY.
-- @treturn TTY A new TTY object which is registered with the kernel. See [the syscall docs](/syscalls/terminal#mkttywidth-number-height-number-tty) for more info.
function terminal.mktty(width, height)
    expect(1, width, "number")
    expect(2, height, "number")
    return util.syscall.mktty(width, height)
end

--- Sets the standard input of the current process.
-- @tparam number|TTY|FileHandle|nil handle The input handle to switch to, as
-- either a physical TTY, a virtual TTY, a file, or nil.
function terminal.stdin(handle)
    expect(1, handle, "number", "table", "nil")
    return util.syscall.stdin(handle)
end

--- Sets the standard output of the current process.
-- @tparam number|TTY|FileHandle|nil handle The output handle to switch to, as
-- either a physical TTY, a virtual TTY, a file, or nil.
function terminal.stdout(handle)
    expect(1, handle, "number", "table", "nil")
    return util.syscall.stdout(handle)
end

--- Sets the standard error of the current process.
-- @tparam number|TTY|FileHandle|nil handle The output handle to switch to, as
-- either a physical TTY, a virtual TTY, a file, or nil.
function terminal.stderr(handle)
    expect(1, handle, "number", "table", "nil")
    return util.syscall.stderr(handle)
end

--- Returns whether the current stdio are linked to a TTY.
-- @treturn boolean Whether the current stdin is linked to a TTY.
-- @treturn boolean Whether the current stdout is linked to a TTY.
function terminal.istty()
    return util.syscall.istty()
end

--- Returns the current size of the TTY if available.
-- @treturn[1] number The width of the screen.
-- @treturn[1] number The height of the screen.
-- @treturn[2] nil If the current stdout is not a screen.
function terminal.termsize()
    return util.syscall.termsize()
end
terminal.getSize = terminal.termsize



--- The Terminal type allows interfacing with the screen in exclusive text mode.
-- It provides the same functions as CraftOS does (with some minor differences),
-- and can be used with minimal conversion.
-- @type Terminal
local Terminal = {}
function Terminal.close() end
function Terminal.write(text) end
function Terminal.blit(text, fg, bg) end
function Terminal.clear() end
function Terminal.clearLine() end
function Terminal.getCursorPos() end
function Terminal.setCursorPos(x, y) end
function Terminal.getCursorBlink() end
function Terminal.setCursorBlink(blink) end
function Terminal.isColor() end
function Terminal.getSize() end
function Terminal.scroll(lines) end
function Terminal.getTextColor() end
function Terminal.setTextColor(color) end
function Terminal.getBackgroundColor() end
function Terminal.setBackgroundColor(color) end
function Terminal.getPaletteColor(color) end
function Terminal.setPaletteColor(color, r, g, b) end
function Terminal.getLine(y) end

--- The GFXTerminal type allows interfacing with the screen in exclusive graphics
-- mode. It provides the same functions as CraftOS-PC does in mode 2, and can be
-- used with minimal conversion.
-- @type GFXTerminal
local GFXTerminal = {}
function GFXTerminal.close() end
function GFXTerminal.getSize() end
function GFXTerminal.clear() end
function GFXTerminal.getPaletteColor(color) end
function GFXTerminal.setPaletteColor(color, r, g, b) end
function GFXTerminal.getPixel(x, y) end
function GFXTerminal.setPixel(x, y, color) end
function GFXTerminal.getPixels(x, y, width, height, asStr) end
function GFXTerminal.drawPixels(x, y, data, width, height) end
function GFXTerminal.getFrozen() end
function GFXTerminal.setFrozen(frozen) end

return terminal