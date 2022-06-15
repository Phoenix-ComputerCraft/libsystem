--- The keys module assigns names to the keycode constants that Phoenix sends in
-- key events, and adds a few functions to make using them easier. This module
-- uses the same names as the CraftOS `keys` API, so porting programs should be
-- trivial.
--
-- @module keys

local keys = {}

-- Letters, numpad numbers and function keys are easy
for i = 0x61, 0x7A do keys[string.char(i)] = i end
for i = 0x81, 0x99 do keys["f" .. bit32.band(i, 31)] = i end
for i = 0xA0, 0xA9 do keys["numPad" .. bit32.band(i, 15)] = i end
-- The rest have to be added manually
keys.backspace = 0x08
keys.tab = 0x09
keys.enter = 0x0A
keys.space = 0x20
keys.apostrophe = 0x27
keys.comma = 0x2C
keys.minus = 0x2D
keys.period = 0x2E
keys.slash = 0x2F
keys.zero = 0x30
keys.one = 0x31
keys.two = 0x32
keys.three = 0x33
keys.four = 0x34
keys.five = 0x35
keys.six = 0x36
keys.seven = 0x37
keys.eight = 0x38
keys.nine = 0x39
keys.semicolon = 0x3B
keys.equals = 0x3D
keys.leftBracket = 0x5B
keys.backslash = 0x5C
keys.rightBracket = 0x5D
keys.grave = 0x60
keys.delete = 0x7F
keys.insert = 0x80
keys.convert = 0x9A
keys.noconvert = 0x9B
keys.kana = 0x9C
keys.kanji = 0x9D
keys.yen = 0x9E
keys.numPadDecimal = 0x9F
keys.numPadAdd = 0xAA
keys.numPadSubtract = 0xAB
keys.numPadMultiply = 0xAC
keys.numPadDivide = 0xAD
keys.numPadEqual = 0xAE
keys.numPadEnter = 0xAF
keys.leftCtrl = 0xB0
keys.rightCtrl = 0xB1
keys.leftAlt = 0xB2
keys.rightAlt = 0xB3
keys.leftShift = 0xB4
keys.rightShift = 0xB5
keys.leftSuper = 0xB6
keys.rightSuper = 0xB7
keys.capsLock = 0xB8
keys.numLock = 0xB9
keys.scrollLock = 0xBA
keys.printScreen = 0xBB
keys.pause = 0xBC
keys.menu = 0xBD
keys.stop = 0xBE
keys.ax = 0xBF
keys.up = 0xC0
keys.down = 0xC1
keys.left = 0xC2
keys.right = 0xC3
keys.pageUp = 0xC4
keys.pageDown = 0xC5
keys.home = 0xC6
keys["end"] = 0xC7
keys.circumflex = 0xC8
keys.at = 0xC9
keys.colon = 0xCA
keys.underscore = 0xCB

local keys_reverse = {}
for k, v in pairs(keys) do keys_reverse[v] = k end

--- Returns the name for the specified keycode.
-- @tparam number id The keycode to check
-- @treturn string|nil The name (which is a key in `keys`), or `nil` if the code is invalid
function keys.getName(id)
    if type(id) ~= "number" then error("bad argument #1 (expected number, got " .. type(id) .. ")", 2) end
    return keys_reverse[id]
end

--- Returns a printable representation of the keycode if available.
-- @tparam number id The keycode to check
-- @treturn string|nil The keycode's character (in lowercase), or `nil` if the code doesn't have a printable representation
function keys.getCharacter(id)
    if type(id) ~= "number" then error("bad argument #1 (expected number, got " .. type(id) .. ")", 2) end
    if (id >= 0x20 and id < 0x7F) or id == 0x0A or id == 0x09 then return string.char(id)
    else return nil end
end

return keys