--------------------------------------------------------------------------------
-- Timed (c) 2011, 2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

TIMED = "Timed"

-- Add-on object ---------------------------------------------------------------

Timed = LibStub("AceAddon-3.0"):NewAddon(
    {
        author      = GetAddOnMetadata(TIMED, "Author"),
        version     = GetAddOnMetadata(TIMED, "Version"),

        cooldowns   = { }, -- player query cooldowns
        gauges      = { }, -- array of threat gauges
        targets     = { }, -- target guids of group members
        threat      = { }, -- threat info array by guid
        versions    = { }, -- player versions
    },

    TIMED,

    -- embeds:
    "AceComm-3.0",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0"
)

-- Variables -------------------------------------------------------------------

-- Upvalues
local Timed         = Timed
local ChatFrame3    = ChatFrame3
local GetNetStats   = GetNetStats
local GetTime       = GetTime
local SendChatMessage = SendChatMessage
local UnitInCombat  = UnitAffectingCombat
local UnitGUID      = UnitGUID
local UnitName      = UnitName
local UnitInRaid    = UnitInRaid
local format        = format
local strjoin       = strjoin
local strsplit      = strsplit
local tconcat       = table.concat
local time          = time

TIMED_PULLAGGRO     = 0
TIMED_OVERAGGRO     = 2
TIMED_TANKING       = 1
TIMED_INSECURE      = 3
TIMED_SAFE          = 4
TIMED_PULLAGGRO_T   = "Pull aggro"

-- Frequently used values
local COMM_DELIM    = "\007"
local COMM_PREFIX   = "TT2"  -- Timed Threat v2
local GUID_NONE     = UnitGUID("none")
local PLAYER        = UnitName("player")

-- Locals updated on :Reconfigure().
local
    autodump,       -- threat info dump to chat frame flag
    interval,       -- min. interval between threat queries per player
    message,        -- query message to be sent
    channel,        -- query message channel    
    threshold,      -- threshold for overaggro warnings
    log,            -- log table reference
    logging,        -- event logging flag
    verbose,        -- verbose mode flag (dumping info to chat frame)
    warnings,       -- enable flag for overaggro warnings
    _               -- dummy

-- Core data storages
local cooldowns     = Timed.cooldowns
local gauges        = Timed.gauges
local threat        = Timed.threat
local targets       = Timed.targets
local versions      = Timed.versions

-- Utils -----------------------------------------------------------------------

local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- Chat functions
function Timed:Printf(...) self:Print(format(...)) end
function Timed:Echo(...) DEFAULT_CHAT_FRAME:AddMessage(format(...)) end

--- Number shortening function
-- @param num (number) Number.
-- @return string - Input number shortened.
function Timed.shorten(num)
    num = tonumber(num) or 0
    if num > 1000000 then
        return format("%.3fm", num / 1000000)
    elseif num > 1000 then
        return format("%.1fk", num / 1000)
    else
        return format("%.1f", num)
    end
end

-- Logging stuff

--- Returns next free log time stamp.
-- @return number - Time stamp.
local function GetLogTimestamp()
    local stamp = time() + GetTime() % 1

    while log[stamp] do
        stamp = stamp + 0.01
    end

    return stamp
end

--- Logs message if logging enabled. Dumps to chat frame if in verbose mode.
-- @param ... (tuple) Arguments to string.format().
function Timed:Log(...)
    if verbose then self:Print(ChatFrame3, format(...)) end
    if logging and log then log[GetLogTimestamp()] = format(...) end
end

--- Returns an iterator to traverse hash indexed table in alphabetical order.
-- @param t (table) Table to traverse.
-- @param f (function|nil) Sort function for table's keys.
-- @return function - Hash table alphabetical iterator.
local function PairsByKeys(t, f) -- from http://www.lua.org/pil/19.3.html
    local a = {}
    local i = 0

    for n in pairs(t) do tinsert(a, n) end
    sort(a, f)

    return function()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]] end
    end
end

--- Dumps all log entries to chat frame.
function Timed:DumpLog()
    self:Print("Saved log data dump:")
    local num = 0
    for stamp, msg in PairsByKeys(self.db.profile.log) do
        self:Echo("   %s: %s", date("%c", stamp), msg)
        num = num + 1
    end
    self:Echo("Total of %d entries.", num)
end

--- Deletes all log entries.
function Timed:PurgeLog()
    local log = self.db.profile.log
    for k in pairs(log) do log[k] = nil end
    self:Print("Log purged.")
end

-- Group functions

--- Checks whether given player is grouped.
-- @param name (string) Player name.
-- @return mixed - Non nil if grouped.
function Timed.IsInGroup(name)
    if not name then name = "player" end
    return UnitInRaid(name) or UnitInParty(name) and GetNumPartyMembers() > 0
end

--- Checks whether unit is in melee range.
-- @param unitID (string) Unit ID.
-- @return boolean - True if in melee range.
function Timed.UnitInMeleeRange(unitID) -- from Threat-2.0
    return UnitExists(unitID)
       and UnitIsVisible(unitID)
       and CheckInteractDistance(unitID, 3)
end

--- Checkes whether unit is a valid threat query subject.
-- @param unit (string) Unit ID.
-- @return boolean - True if valid for querying.
function Timed.UnitIsQueryable(unit)
    return UnitExists(unit)
       and not UnitIsPlayer(unit)
       and not UnitIsFriend(unit, "player")
end

-- Time functions

--- Returns lag info.
-- @return number - Lag in seconds.
function Timed.GetLag()
    return select(3, GetNetStats()) / 1000
end

--- Converts relative to absolute time.
-- @param time (number) Relative time.
-- @return number - Absolute time.
function Timed.Rel2AbsTime(time)
    return GetTime() + time
end

--- Converts absolute to relative time.
-- @param time (number) Absolute time.
-- @return number - Relative time.
function Timed.Abs2RelTime(time)
    return time - GetTime()
end

-- Localize functions
local Abs2RelTime = Timed.Abs2RelTime
local GetLag = Timed.GetLag
local IsInGroup = Timed.IsInGroup
local Rel2AbsTime = Timed.Rel2AbsTime
local UnitInMeleeRange = Timed.UnitInMeleeRange
local UnitIsQueryable = Timed.UnitIsQueryable

-- Event handlers --------------------------------------------------------------

--- Timed enable handler.
function Timed:OnEnable()
    self:SetTarget(PLAYER, GUID_NONE, NONE)
    self:Reconfigure()

    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_FLAGS")

    self:RegisterMessage("TIMED_TARGET_UPDATE")
    self:RegisterMessage("TIMED_THREAT_UPDATE")

    self:RegisterComm(COMM_PREFIX, "CHAT_MSG_ADDON")

    self:PLAYER_TARGET_CHANGED()
    self:PARTY_MEMBERS_CHANGED()
end

--- Timed disable handler.
function Timed:OnDisable()
    --TODO:
    -- join empty queue
end

do
    local data = {}

    --- System message filter.
    -- @param msg (string) Message.
    -- @return boolean - Whether to filter out the message.
    -- @return string|nil - Input message if not filtered out.
    function Timed:CHAT_MSG_SYSTEM(msg)
        if msg:sub(1, 11) == "Threat list" then
            for k in pairs(data) do
                data[k] = nil
            end

            return true

        elseif msg:sub(1, 13) == "End of threat" then
            local guid = UnitGUID("target")
            local thr = tconcat(data, COMM_DELIM)
            self:Log("Threat info: %s -> sent", thr:gsub(COMM_DELIM, "/"), PLAYER)

            self:SetCooldown(PLAYER, Rel2AbsTime(interval - 3 * GetLag()))

            if self:SetThreat(guid, thr) and IsInGroup() then
                self:SendThreat(guid)
            end

            if UnitInCombat("target") and UnitIsQueryable("target") then
                self:RecalculateQueryTimer()
            end

            return true
        end

        local pos, unit, threat =
            msg:match("(%d+)\.%s+(.-)%s+[(]guid .+[)]%s+\-%s+threat%s+(.+)%s*")

        if unit and threat then
            data[tonumber(pos)] = format("%s%s%.2f", unit, COMM_DELIM,
                tonumber(threat) or 0)

            return true
        end

        return false, msg
    end
end

do
    local was

    --- Group roster update handler.
    -- @param e (string) Event name.
    function Timed:PARTY_MEMBERS_CHANGED(e)
        local is = IsInGroup()

        if is and not was then
            self:SendHello()
        end

        for name in pairs(targets) do
            if name ~= PLAYER and not IsInGroup(name) then
                targets[name] = nil
            end
        end

        was = is
    end
end

--- Player target change handler.
-- @param e (string) Event name.
function Timed:PLAYER_TARGET_CHANGED(e)
    local unit = "target"
    local guid = UnitIsQueryable(unit) and UnitGUID(unit) or GUID_NONE

    if self:GetTarget(PLAYER) ~= guid then
        self:SetTarget(PLAYER, guid, UnitName(unit) or NONE)
        if IsInGroup() then self:SendTarget() end
    end

    self:UNIT_FLAGS(e, unit)
end

--- Unit flags update handler.
-- @param e (string) Event name.
-- @param unit (string) Unit ID.
function Timed:UNIT_FLAGS(e, unit)
    if unit ~= "target" then return end

    if UnitInCombat(unit) and UnitIsQueryable(unit) then
        self:RecalculateQueryTimer()
    end
end

-- Timed specific events

--- Called when group member changes target.
-- @param e (string) Event name.
-- @param player (string) Unit name.
-- @param guid (string) Target GUID.
-- @param name (string) Target name.
function Timed:TIMED_TARGET_UPDATE(e, player, guid, name)
    if name then
        self:Log("%s targeted %s (%d |4player:players; targeting).", player, name, self:GetQueueCount(guid))
    end
end

--- Called when unit threat changes.
-- @param e (string) Event name.
-- @param guid (string) Unit GUID.
-- @param ... (tuple) Tuple of any number of <unit, threat> pairs.
function Timed:TIMED_THREAT_UPDATE(e, guid, ...)
    for gid, gauge in pairs(gauges) do
        gauge:Update(guid, ...)
    end
end

-- Core ------------------------------------------------------------------------

--- Returns query cooldown of specified player.
-- @param player (string) Unit name.
-- @return number|nil Cooldown.
function Timed:GetCooldown(player)
    return cooldowns[assert(player)]
end

--- Returns count of players in specified queue.
-- @param guid (string) Unit GUID.
-- @return number Queue count (size).
function Timed:GetQueueCount(guid)
    count = 0

    for player, target in pairs(targets) do
        if target == guid then
            count = count + 1
        end
    end

    return count
end

--- Returns specified player's queue position.
-- @param player (string) Player name.
function Timed:GetQueuePosition(player)
    local _cooldown = self:GetCooldown(player)
    local _target = self:GetTarget(player)
    local pos = 1

    for player, cooldown in pairs(cooldowns) do
        if self:GetTarget(player) == _target and cooldown < _cooldown then
            pos = pos + 1
        end
    end

    return pos
end

--- Returns target GUID of specified player.
-- @param player (string) Player name.
-- @return string|nil - Target GUID.
function Timed:GetTarget(player)
    return targets[assert(player)]
end

--- Returns threat information string for unit.
-- @param guid (string) Unit GUID.
-- @return string|nil - Threat data separated by COMM_DELIM.
function Timed:GetThreat(guid)
    return threat[assert(guid)]
end

--- Returns Timed version of specified player.
-- @param player (string) Unit name.
-- @return number|nil - Version number.
function Timed:GetVersion(player)
    return versions[assert(player)]
end

--- Returns numeric version of the add-on.
function Timed:GetVersionNumber()
    local a, b, c = self.version:match("(%d*)%D*(%d*)%D*(%d*)")
    return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
end

--- Sets cooldown for specified player.
-- @param player (string) Player name.
-- @param time (number) Query cooldown.
function Timed:SetCooldown(player, time)
    cooldowns[assert(player)] = tonumber(time) or 0
    self:SendMessage("TIMED_COOLDOWN_UPDATE", player, time)
end

--- Sets target GUID for specified player.
-- @param player (string) Player name.
-- @param guid (string) Target GUID.
-- @param name (string|nil) Target name.
function Timed:SetTarget(player, guid, name)
    targets[assert(player)] = guid
    self:SendMessage("TIMED_TARGET_UPDATE", player, guid, name)
end

--- Sets threat info string for specified unit.
-- @param guid (string) Unit GUID.
-- @param info (string|nil) Threat info string.
-- @return boolean - Whether broadcast to group.
function Timed:SetThreat(guid, info)
    info = info ~= "" and info or nil
    threat[assert(guid)] = info
    self:SendMessage("TIMED_THREAT_UPDATE", guid, strsplit(COMM_DELIM, info or ""))

    return not not info
end

--- Sets add-on version for specified player.
-- @param player (string) Player name.
-- @param version (number|nil) Version.
function Timed:SetVersion(player, version)
    versions[player] = version
    self:SendMessage("TIMED_VERSION_UPDATE", player, version)
end

--- Sends current target to player or group if no player specified.
-- @param player (string|nil) Target player or nil if group broadcast.
function Timed:SendTarget(player)
    self:SendComm(player, "Q", self:GetTarget(PLAYER), UnitName("target") or NONE)
end

--- Sends threat info to group.
-- @param guid (string) Unit GUID.
function Timed:SendThreat(guid)
    self:SendComm(nil, "T", guid, ceil(Abs2RelTime(self:GetCooldown(PLAYER)) * 10),
        assert(self:GetThreat(guid)))
end

--- Sends hello message to player or group if no player specified.
-- @param player (string|nil) Target player or nil if group broadcast.
function Timed:SendHello(player)
    self:SendComm(player, "H", self:GetTarget(PLAYER), ceil(Abs2RelTime(
        self:GetCooldown(PLAYER)) * 10), self:GetVersionNumber())
end

--- Queries threat list.
function Timed:QueryThreat()
    if UnitInCombat("target") and UnitIsQueryable("target") then
        SendChatMessage(message, channel)
    end
end

function Timed:RecalculateQueryTimer()
    local num = self:GetQueueCount(self:GetTarget(PLAYER))
    local pos = self:GetQueuePosition(PLAYER)

    self:CancelAllTimers()
    self:ScheduleTimer("QueryThreat", interval/num * pos)
end

--- Reconfigures variables for speed-up.
function Timed:Reconfigure()
    local db = self.db.profile

    autodump    = db.autodump
    interval    = db.interval
    log         = db.log
    logging     = db.logging
    message     = db.message
    channel     = db.channel
    threshold   = db.threshold
    verbose     = db.verbose
    warnings    = db.warnings
end

-- Gauge management functions --------------------------------------------------

--- Creates threat gauge that can be saved between sessions.
-- Gauge will be saved between sessions unless fixed flag is set.
-- @param unit (string) Unit ID.
-- @param fixed (boolean) Fixed unit flag.
function Timed:AddGauge(unit, fixed)
    local gauge = self:CreateGauge(unit, fixed)
    if not fixed then self.db.profile.gauges[gauge:UnitToken()] = true end
    return gauge
end

--- Creates threat gauge object and adds it to active gauge list.
-- @param unit (string) Unit ID.
-- @param fixed (boolean) Fixed unit flag.
function Timed:CreateGauge(unit, fixed)
    assert(not gauges[fixed and UnitGUID(unit) or unit],
        format("CreateGauge: Gauge %q already exists.",
            fixed and UnitGUID(unit) or unit))

    local gauge = self.Gauge:New(unit, fixed)
    gauges[gauge:UnitToken()] = gauge
    return gauge
end

--- Deletes given threat gauge. Calls its OnRelease handler.
-- @param gid (string) Gauge ID.
function Timed:DeleteGauge(gid)
    assert(gid, "DeleteGauge: No GID specified.")

    local gauge = assert(gauges[gid],
        format("DeleteGauge: Gauge %q does not exist.", gid))

    self.db.profile.gauges[gauge:UnitToken()] = nil
    gauges[gauge:UnitToken()] = nil
    gauge:Release()
end

--- Loads saved gauges on initialization.
function Timed:LoadGauges()
    for unit in pairs(self.db.profile.gauges) do
        self:CreateGauge(unit)
    end

    self:UnregisterEvent("VARIABLES_LOADED")
end

--[[-- Communication -----------------------------------------------------------

Timed protocol
    Consequent fields in comms are separated by COMM_DELIM, represented below as `:`.

    H:<guid>:<cooldown>:<version>
    Hello packet (group or whisper). Query if at group or reply if at whisper.
        guid        Sender target's GUID.
        cooldown    Sender's query cooldown.
        version     Sender's version.

    Q:<guid>:<name>
    Queue info packet (group or whisper).
        guid        New target GUID.
        name        New target name.

    T:<guid>:<cooldown>:<threat>
    Threat info packet (group only).
        guid        Target GUID.
        cooldown    Sender's query cooldown.
        threat      Threat information in form of <unit:threat> pairs.

--]]----------------------------------------------------------------------------

--- Add-on message handler.
-- @param e (string) Event name.
-- @param msg (string) Message.
-- @param distr (string) Distribution.
-- @param sender (string) Sender.
function Timed:CHAT_MSG_ADDON(e, msg, distr, sender)
    if sender == PLAYER or not IsInGroup(sender) or distr == "UNKNOWN" then
        return
    end

    local type, A, B, C = strsplit(COMM_DELIM, msg, 4)

    if type == "T" then -- guid, cooldown, threat
        self:SetCooldown(sender, Rel2AbsTime((tonumber(B) or 0) / 10 - GetLag()))
        self:SetThreat(A, C)
        self:Log("Threat info: %s <- received from %s", C:gsub(COMM_DELIM, "/"), sender)

        if A == self:GetTarget(PLAYER)
        and UnitInCombat("target")
        and UnitIsQueryable("target") then
            self:RecalculateQueryTimer()
        end

    elseif type == "Q" then -- guid, name
        self:SetTarget(sender, A, B or UNKNOWN)

    elseif type == "H" then -- guid, cooldown, version
        self:SetTarget(sender, A)
        self:SetCooldown(sender, Rel2AbsTime((tonumber(B) or 0) / 10 - GetLag()))
        self:SetVersion(sender, tonumber(C))

        if distr ~= "WHISPER" then
            self:SendHello(sender)
        end
    end
end

--- Sends add-on comm messages.
-- @param target (string|nil) Target player or nil if group broadcast.
-- @param ... (tuple) Data to send.
function Timed:SendComm(target, ...)
    self:SendCommMessage(COMM_PREFIX, strjoin(COMM_DELIM, ...),
        target and "WHISPER" or UnitInRaid("player") and "RAID" or "PARTY",
        target)
end

-- Initialization --------------------------------------------------------------

--- Timed initialize handler.
function Timed:OnInitialize()
    self:SetCooldown(PLAYER, GetTime())
    self:SetVersion(PLAYER, self:GetVersionNumber())

    -- initialize database
    self.db = LibStub("AceDB-3.0"):New("Timed2DB", {
        profile = {
            autodump    = true,
            gauges      = { target = true },
            interval    = 10.0,
            log         = {},
            logging     = false,
            message     = ".deb thr",
            channel     = "GUILD",
            threshold   = 0.75,
            verbose     = false,
            warnings    = true,
        }
    }, DEFAULT)

    -- add system message filter
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(msg)
        return self:CHAT_MSG_SYSTEM(msg)
    end)

    -- slash command
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Timed", self.slash)
    self:RegisterChatCommand("timed", "OnSlashCmd")

    -- interface options stuff
    self.options = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Timed", "Timed")
    self.options.default = function() self.db:ResetProfile() self:Reconfigure() end

    -- load gauges on time
    self:RegisterEvent("VARIABLES_LOADED", "LoadGauges")

    -- prevent next calls
    self.OnInitialize = nil
end
