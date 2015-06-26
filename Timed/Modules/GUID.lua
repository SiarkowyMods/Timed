--------------------------------------------------------------------------------
-- Timed (c) 2011 by Siarkowy <http://siarkowy.net/timed>
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

--
-- GUID COMPRESSION UTIL
--

local string_char, string_match, string_byte = string.char, string.match, string.byte
local gsub = string.gsub

--
-- UTIL
--

local compress, decompress

function compress(guid)
    guid = string_match(guid, "^0x(.+)$")
    for i = string_byte("0"), string_byte("9") do
        for t = 25, 3, -1 do
            guid = gsub(guid, strrep(string_char(i), t), string_char(i) .. string_char(94 + t))
        end
    end
    for i = string_byte("A"), string_byte("F") do
        for t = 25, 3, -1 do
            guid = gsub(guid, strrep(string_char(i), t), string_char(i) .. string_char(94 + t))
        end
    end
    return guid
end

do
    local function decompress_helper(x, t)
        return strrep(x, t:byte() - 94)
    end

    function decompress(guid)
        return "0x" .. gsub(guid, "(.)([a-w])", decompress_helper)
    end
end

Timed.util = Timed.util or { }
Timed.util.compress = compress
Timed.util.decompress = decompress
