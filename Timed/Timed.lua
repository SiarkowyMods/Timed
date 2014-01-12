--------------------------------------------------------------------------------
-- Timed (c) 2011-2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

TIMED = "Timed"

-- Addon object ----------------------------------------------------------------

Timed = LibStub("AceAddon-3.0"):NewAddon(
    {
        author = GetAddOnMetadata(TIMED, "Author"),
        gauges = { },   -- array of threat gauges
        targets = { },  -- target guids of group members
        threat = { },   -- threat info array by guid
        version = GetAddOnMetadata(TIMED, "Version"),
        versions = { }, -- player versions
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
local Timed = Timed
local ChatFrame3 = ChatFrame3
local GetTime = GetTime
local UnitAffectingCombat = UnitAffectingCombat
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitInRaid = UnitInRaid
local format = format
local strjoin = strjoin
local strsplit = strsplit
local tconcat = table.concat
local time = time

-- Frequently used values
local COMM_DELIM    = "\007"
local THR_DELIM     = "~"
local COMM_PREFIX   = "TT2"  -- Timed Threat v2
local GUID_NONE     = UnitGUID("none")
local PLAYER        = UnitName("player")

-- Locals updated on :Reconfigure().
local
    autodump,       -- threat info dump to chat frame flag
    interval,       -- min. interval between threat queries per player
    message,        -- query message to be sent
    threshold,      -- threshold for overaggro warnings
    log,            -- log table reference
    logging,        -- event logging flag
    verbose,        -- verbose mode flag (dumping info to chat frame)
    warnings,       -- enable flag for overaggro warnings
    _               -- dummy

-- Core data storages
local gauges = Timed.gauges
local threat = Timed.threat
local targets = Timed.targets
local versions = Timed.versions

-- Utils -----------------------------------------------------------------------

local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- Chat functions
function Timed:Printf(...) self:Print(format(...)) end
function Timed:Echo(...) DEFAULT_CHAT_FRAME:AddMessage(format(...)) end

-- Logging stuff
function Timed:Log(...)
    if verbose then self:Print(ChatFrame3, format(...)) end
    if logging and log then log[time() + GetTime() % 1] = format(...) end
end

-- Group functions
function Timed.IsInGroup()
    return UnitInRaid("player") or GetNumPartyMembers() > 0
end

function Timed.UnitInMeleeRange(unitID) -- from Threat-2.0
    return UnitExists(unitID)
       and UnitIsVisible(unitID)
       and CheckInteractDistance(unitID, 3)
end

function Timed.UnitIsQueryable(unit)
    return UnitExists(unit)
        and UnitAffectingCombat(unit)
        and not UnitIsDead(unit)
        and not UnitIsPlayer(unit)
        and not UnitIsFriend(unit, "player")
end

-- Localize functions
local IsInGroup = Timed.IsInGroup
local UnitInMeleeRange = Timed.UnitInMeleeRange
local UnitIsQueryable = Timed.UnitIsQueryable

-- Core ------------------------------------------------------------------------

function Timed:OnEnable()
    self:SetTarget(PLAYER, GUID_NONE)
    self:Reconfigure()

    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_FLAGS", "PLAYER_TARGET_CHANGED")

    self:RegisterMessage("TIMED_COOLDOWN_UPDATE", self.Print)
    self:RegisterMessage("TIMED_TARGET_UPDATE")
    self:RegisterMessage("TIMED_THREAT_UPDATE")
    self:RegisterMessage("TIMED_VERSION_UPDATE", self.Print)

    self:RegisterComm(COMM_PREFIX, "CHAT_MSG_ADDON")

    self:PLAYER_TARGET_CHANGED()
    self:PARTY_MEMBERS_CHANGED()
end

function Timed:OnDisable()
    --TODO:
    -- join empty queue
end

do
    local data
    local filter
    local toggle

    function Timed:CHAT_MSG_SYSTEM(e, msg)
        if msg:sub(1, 11) == "Threat list" then
            filter = true

            for k in pairs(data) do
                data[k] = nil
            end

            return
        end

        if msg:sub(1, 13) == "End of threat" then
            toggle = true

            local guid = UnitGUID("target")
            local thr = tconcat(data, COMM_DELIM)

            self:SetThreat(guid, thr)
            if IsInGroup() then
                self:SendThreat(guid)
            end

            return
        end

        local pos, unit, threat =
            msg:match("(%d+)\.%s+(.-)%s+[(]guid .+[)]%s+\-%s+threat%s+(.+)%s*")

        if unit and threat then
            data[tonumber(pos)] = format("%s%s%.2f", unit, THR_DELIM,
                tonumber(threat) or 0)
        end
    end

    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(msg)
        if toggle then
            filter = nil
            toggle = nil

            return true, msg
        end

        return filter, msg
    end)
end

do
    local was

    function Timed:PARTY_MEMBERS_CHANGED(e)
        local is = IsInGroup()

        if is and not was then
            self:SendVersion(nil)
        end

        local UnitInGroup = UnitInRaid("player") and UnitInRaid or UnitInParty

        for name in pairs(targets) do
            if not UnitInGroup(name) then
                targets[name] = nil
            end
        end

        was = is
    end
end

function Timed:PLAYER_TARGET_CHANGED(e, unit)
    unit = unit or "target"

    if unit ~= "target" then -- can be different because of UNIT_FLAGS
        return
    end

    local guid = UnitIsQueryable(unit) and UnitGUID(unit) or GUID_NONE

    if self:GetTarget(PLAYER) == guid then -- no target change
        return
    end

    self:SetTarget(PLAYER, guid)

    if IsInGroup() then
        self:SendTarget()
    end
end

function Timed:TIMED_TARGET_UPDATE(e, player, guid)
    self:Log("%s targeted %s.", player, guid)
end

function Timed:TIMED_THREAT_UPDATE(e, guid, info)
    for gid, gauge in pairs(gauges) do
        gauge:Update(guid, info)
    end
end

function Timed:GetCooldown(player)
    return targets[assert(player)]
end

function Timed:GetTarget(player)
    return targets[assert(player)]
end

function Timed:GetThreat(guid)
    return threat[assert(guid)]
end

function Timed:GetVersion(player)
    return versions[assert(player)]
end

function Timed:SetCooldown(player, time)
    cooldowns[assert(player)] = assert(tonumber(time))
end

function Timed:SetTarget(player, guid)
    targets[assert(player)] = guid
    self:SendMessage("TIMED_TARGET_UPDATE", player, guid)
end

function Timed:SetThreat(guid, info)
    threat[assert(guid)] = info
    self:SendMessage("TIMED_THREAT_UPDATE", guid, info)
end

function Timed:SetVersion(player, version)
    versions[player] = version
    self:SendMessage("TIMED_VERSION_UPDATE", player, version)
end

function Timed:SendCooldown(player)
    self:SendComm(player, "C", self:GetCooldown(PLAYER))
end

function Timed:SendTarget(player)
    self:SendComm(player, "Q", self:GetTarget(PLAYER))
end

function Timed:SendThreat(guid)
    self:SendComm(nil, "T", guid, assert(self:GetThreat(guid)))
end

function Timed:SendVersion(player)
    self:SendComm(player, "V", self.version)
end

--- Loads saved gauges on Timed initialization.
function Timed:LoadGauges()
    for unit in pairs(self.db.profile.gauges) do
        self:CreateGauge(unit)
    end

    self:UnregisterEvent("VARIABLES_LOADED")
end

function Timed:Reconfigure()
    local db = self.db.profile

    autodump    = db.autodump
    interval    = db.interval
    log         = db.log
    logging     = db.logging
    message     = db.message
    threshold   = db.threshold
    verbose     = db.verbose
    warnings    = db.warnings
end

-- Gauge management functions --------------------------------------------------

--- Creates threat gauge that can be saved between sessions.
-- @param unit (string) Unit ID for new gauge.
-- @param const (boolean) Flag stating wheter save gauge between sessions.
function Timed:AddGauge(unit, const)
    local gauge = self:CreateGauge(unit, const)
    if not const then self.db.profile.gauges[gauge:UnitToken()] = true end
    return gauge
end

--- Creates threat gauge.
-- @param unit (string) Unit ID for new gauge.
-- @param const (boolean) Whether name and guid are constant or from self.unit.
function Timed:CreateGauge(unit, const)
    assert(not gauges[const and UnitGUID(unit) or unit],
        format("CreateGauge: Gauge %q already exists.",
            const and UnitGUID(unit) or unit))

    local gauge = self.Gauge:New(unit, const)
    gauges[gauge:UnitToken()] = gauge

    return gauge
end

--- Deletes given threat gauge.
-- @param gid (string) Gauge ID to delete.
function Timed:DeleteGauge(gid)
    assert(gid, "DeleteGauge: No GID specified.")

    local gauge = assert(gauges[gid],
        format("DeleteGauge: Gauge %q does not exist.", gid))

    self.db.profile.gauges[gauge:UnitToken()] = nil
    gauges[gauge:UnitToken()] = nil
    gauge:Release()
end

--[[-- Comm --------------------------------------------------------------------

Protocol:
    T guid threat (group only)
        Threat info packet.

    C time (group/whisper)
        Command cooldown info. Sent with .debug threatlist query.

    Q guid (group/whisper)
        Queue info packet.

    V version (group/whisper)
        Version info packet. Query if at group or reply if at whisper.

--]]----------------------------------------------------------------------------

function Timed:CHAT_MSG_ADDON(msg, distr, sender)
    if not UnitInRaid(sender) and not UnitInParty(sender)
    or distr == "UNKNOWN" then
        return
    end

    local type, param, data = strsplit(COMM_DELIM, msg, 3)

    if type == "T" then                 -- threat info:
        self:SetThreat(param, data)     -- guid, threat

    elseif type == "C" then             -- cooldown info:
        self:SetCooldown(sender, param) -- player, time

    elseif type == "Q" then             -- queue info:
        self:SetTarget(sender, param)   -- player, guid

    elseif type == "V" then             -- version info:
        self:SetVersion(sender, param)  -- player, version

        if distr ~= "WHISPER" then      -- @group
            self:SendVersion(sender)
            self:SendTarget(sender)
            self:SendCooldown(sender)
        end
    end
end

function Timed:SendComm(target, ...)
    self:SendCommMessage(COMM_PREFIX, strjoin(COMM_DELIM, ...),
        target and "WHISPER" or UnitInRaid("player") and "RAID" or "PARTY",
        target)
end

-- Initialization --------------------------------------------------------------

function Timed:OnInitialize()
    self:SetVersion(PLAYER, self.version)

    -- initialize database
    self.db = LibStub("AceDB-3.0"):New("Timed2DB", {
        profile = {
            autodump    = true,
            gauges      = { target = true },
            interval    = 10,
            log         = {},
            logging     = false,
            message     = ".debug threatlist",
            threshold   = 0.75,
            verbose     = false,
            warnings    = true,
        }
    }, DEFAULT)

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
