--------------------------------------------------------------------------------
-- Timed (c) 2011-2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

TIMED = "Timed"

-- Addon object ----------------------------------------------------------------

Timed = LibStub("AceAddon-3.0"):NewAddon(
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
local time = time

-- Frequently used values
local COMM_DELIM    = "|"
local COMM_PREFIX   = "TT2"  -- Timed Threat
local GUID_NONE     = UnitGUID("none")
local PLAYER        = UnitName("player")

-- Threat situation levels
local SITUATION_SAFE        = 1
local SITUATION_UNSAFE      = 2
local SITUATION_TANKING     = 3
local SITUATION_OVERAGGRO   = 4

-- Threat situation labels
local SITUATIONS = {
    SITUATION_SAFE          = "Safe",
    SITUATION_UNSAFE        = "Unsafe",
    SITUATION_TANKING       = "Tanking",
    SITUATION_OVERAGGRO     = "Overaggroing",
}

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
local gauges = { }  -- array of threat gauges
local threat = { }  -- threat info array by guid
local targets = { } -- target guids of group members

-- Make some locals accessible
Timed.gauges = gauges
Timed.threat = threat
Timed.targets = targets

-- Utils -----------------------------------------------------------------------

local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- Chat functions
function Timed:Printf(...) self:Print(format(...)) end
function Timed:Echo(...) DEFAULT_CHAT_FRAME:AddMessage(format(...)) end

-- Group and aggro functions
function Timed.GetThreatSituation(factor)
    if factor > 1 then return SITUATION_OVERAGGRO
    elseif factor == 1 then return SITUATION_TANKING
    elseif factor >= 0.75 then return SITUATION_UNSAFE
    else return SITUATION_SAFE end
end

function Timed.IsInGroup()
    return UnitInRaid("player") or GetNumPartyMembers() > 0
end

function Timed.UnitInMeleeRange(unitID) -- from Threat-2.0
    return UnitExists(unitID)
       and UnitIsVisible(unitID)
       and CheckInteractDistance(unitID, 3)
end

function Timed.UnitIsQueryable(unit)
    return UnitExists("target")
        and not UnitIsPlayer("target")
        and not UnitIsFriend("target", "player")
end

-- Localize some functions
local IsInGroup = Timed.IsInGroup
local UnitIsQueryable = Timed.UnitIsQueryable

-- Core ------------------------------------------------------------------------

function Timed:OnEnable()
    self:Reconfigure()

    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnPartyUpdate")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetUpdate")
    self:RegisterEvent("UNIT_FLAGS", "OnTargetUpdate")
    self:RegisterComm(COMM_PREFIX, "OnCommReceived")
    self:RegisterMessage("TIMED_THREAT_UPDATE", "OnThreatUpdate")

    self:OnPartyUpdate()
    self:OnTargetUpdate()

    --DEBUG
    self:ScheduleRepeatingTimer(function() self:OnThreatUpdate(UnitGUID("player"), 2, "u1", 3, "u2", 2, "u3", 1) end, 3)
end

function Timed:OnDisable()
    --TODO:
    -- join empty queue
end

do
    local was

    function Timed:OnPartyUpdate()
        self:Print("OnPartyUpdate()") --DEBUG

        local is = IsInGroup()

        if not was and is then
            -- broadcast version --TODO
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

function Timed:OnTargetUpdate(_, unit)
    if unit and unit ~= "target" then
        return
    end

    local guid = UnitIsQueryable("target") and UnitGUID("target") or GUID_NONE

    if self:GetTarget(PLAYER) == guid then
        return
    end

    self:SetTarget(PLAYER, guid)

    if IsInGroup() then
        self:SendGroupComm("Q", guid)
    end

    local unit = "target"
    self:Printf("Target: %s <%s> <combat: %d> <alive: %s>", unit, UnitName(unit) or NONE, UnitAffectingCombat("target") or 0, not UnitIsDead(unit) and 1 or 0)
end

function Timed:OnThreatUpdate(guid, tank, ...)
    for gid, gauge in pairs(gauges) do
        gauge:Update(guid, tank, ...)
    end
end

function Timed:Log(...)
    if verbose then self:Print(ChatFrame3, format(...)) end
    if logging then log[time() + GetTime() % 1] = format(...) end
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

function Timed:GetTarget(player)
    return targets[player]
end

function Timed:SetTarget(player, guid)
    assert(player and guid)
    targets[player] = guid
    self:Log("%s targeted %s.", player, guid)
end

--- Loads saved gauges on Timed initialization.
function Timed:LoadGauges()
    for unit in pairs(self.db.profile.gauges) do
        self:CreateGauge(unit)
    end

    self:UnregisterEvent("VARIABLES_LOADED")
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
-- @param const (boolean) If true, name and guid are constant, otherwise calculated from self.unit.
function Timed:CreateGauge(unit, const)
    assert(not gauges[const and UnitGUID(unit) or unit],
        format("CreateGauge: Gauge %q already exists.", const and UnitGUID(unit) or unit))

    local gauge = self.Gauge:New(unit, const)
    gauges[gauge:UnitToken()] = gauge

    return gauge
end

--- Deletes given threat gauge.
-- @param gid (string) Gauge ID to delete.
function Timed:DeleteGauge(gid)
    assert(gid, "DeleteGauge: No GID specified.")

    local gauge = assert(gauges[gid], format("DeleteGauge: Gauge %q does not exist.", gid))
    self.db.profile.gauges[gauge:UnitToken()] = nil
    gauges[gauge:UnitToken()] = nil
    gauge:Release()
end

-- Comm ------------------------------------------------------------------------

function Timed:OnCommReceived(...)
    self:Print(...)
end

function Timed:SendGroupComm(...)
    self:SendCommMessage(COMM_PREFIX, strjoin(COMM_DELIM, ...),
        UnitInRaid("player") and "RAID" or "PARTY")
end

function Timed:SendWhisperComm(target, ...)
    self:SendCommMessage(COMM_PREFIX, strjoin(COMM_DELIM, ...),
        "WHISPER", target)
end

-- Initialization --------------------------------------------------------------

function Timed:OnInitialize()
    local defaults = {
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
    }

    -- initialize database
    self.db = LibStub("AceDB-3.0"):New("Timed2DB", defaults, DEFAULT)

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
