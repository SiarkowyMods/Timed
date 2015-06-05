--------------------------------------------------------------------------------
-- Timed (c) 2011 by Siarkowy <http://siarkowy.net/timed>
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

--
-- UTIL
--

function Timed:ListVersions()
    self:Print("Roster versions:")
    local version = self.version
    local i = 0
    for n, v in pairs(self.versions) do
        i = i + 1
        DEFAULT_CHAT_FRAME:AddMessage(format("   %d. %s %s%s|r", i, n, v == version and "|cff33ff33" or "|cffff3333", v))
    end
end

function Timed:RegisterVersion(player, version)
    self.versions[player] = version
end

local published = false

function Timed:PARTY_MEMBERS_CHANGED()
    local ingroup = UnitInRaid("player")
    if not ingroup then
        published = false
        return
    end

    if not published and ingroup then
        self:BroadcastHello()
        published = true
    end
end

--
-- COMM
--

function Timed:BroadcastHello()
    self:SendCommMessage("GROUP", "HELLO", self.version)
end

function Timed.OnCommReceive:HELLO(prefix, sender, distribution, version)
    self:RegisterVersion(sender, version)
    self:SendCommMessage("WHISPER", sender, "HELLO_REPLY", self.version)
end

function Timed.OnCommReceive:HELLO_REPLY(prefix, sender, distribution, version)
    self:RegisterVersion(sender, version)
end
