--------------------------------------------------------------------------------
-- Timed (c) 2011, 2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

-- Variables -------------------------------------------------------------------

local assert        = assert
local pairs         = pairs
local rawget        = rawget
local shorten       = Timed.shorten
local UnitExists    = UnitExists
local UnitGUID      = UnitGUID
local UnitInMeleeRange = Timed.UnitInMeleeRange
local UnitName      = UnitName

-- Threat gauge object stuff ---------------------------------------------------

--- Gauge prototype
local Gauge = { }
Gauge.__meta = { __index = Gauge }

--- Creates new gauge object and initializes it.
-- If fixed flag is set, save GUID/name parameters only once.
-- Otherwise return variable parameters based on unit ID.
-- @param unit (string) Unit ID for new gauge.
-- @param fixed (boolean) Fixed unit flag.
-- @return table - The gauge object.
function Gauge:New(unit, fixed)
    assert(unit, "No unit specified to Gauge:New().")
    assert(not fixed or UnitExists(unit), format("Unit %s does not exist.", unit))

    local gauge = setmetatable({
        unit = not fixed and unit or nil, -- unit ID if variable
        guid = fixed and UnitGUID(unit) or nil, -- GUID if fixed
        name = fixed and UnitName(unit) or nil, -- unit name if fixed
    }, self.__meta)

    gauge:Init()

    return gauge
end

--- Initializes the object. Called internally by Init().
-- This should be overwritten or hooked if desired.
function Gauge:OnInitialize()
    -- self:Print("Gauge %s initialized.", self:UnitToken())
end

--- Clears user data. Called internally by Release().
-- This should be overwritten or hooked if desired.
function Gauge:OnRelease()
    -- self:Print("Gauge %s released.", self:UnitToken())
    for k, _ in pairs(self) do self[k] = nil end
end

--- Handles threat data update. Called internally by Update().
-- This should be overwritten or hooked if desired.
-- @param guid (string) Unit GUID.
-- @param ... (tuple) Tuple of any number of <unit, threat> pairs.
function Gauge:OnUpdate(guid, ...)
    if not Timed.db.profile.autodump then return end

    local unit, threat, ratio
    local pullaggro = select(2, ...)

    if not pullaggro then
        return
    end

    pullaggro = pullaggro * (not UnitInMeleeRange(self:UnitToken())
        and 1.3 or 1.1)

    Timed:Printf("Threat info for %s", self:UnitName())

    for i = 1, select("#", ...), 2 do
        unit, threat = select(i, ...)
        ratio = threat/pullaggro

        self:Print("%s %s %s (%d%%)", strrep("||", ratio * 10),
            unit, shorten(threat), ratio * 100)
    end
end

--- Prints formatted data to chat frame.
-- @param f (string) Message format.
-- @param ... (tuple) Argument list to format.
function Gauge:Print(f, ...)
    DEFAULT_CHAT_FRAME:AddMessage(format(f, ...))
end

--- Returns nominal queue interval for current gauge.
-- @return number - Nominal interval.
function Gauge:GetNominalInterval()
    local count = self:GetQueueCount()
    return Timed:GetQueryInterval() / (count > 0 and count or 1)
end

--- Returns queue size.
-- @return number - Queue size.
function Gauge:GetQueueCount()
    return Timed:GetQueueCount(self:UnitGUID())
end

--- Returns unit GUID of the gauge.
-- @return string|nil - Unit GUID.
function Gauge:UnitGUID()
    return self.guid or UnitGUID(self.unit)
end

--- Returns unit name of the gauge.
-- @return string|nil - Unit name.
function Gauge:UnitName()
    return self.name or UnitName(self.unit)
end

--- Returns unit token of the gauge.
-- @return string|nil - Unit token.
function Gauge:UnitToken()
    return self.unit or self.guid
end

--- Calls OnInitialize() if exists.
function Gauge:Init()
    return self.OnInitialize and self:OnInitialize()
end

--- Calls OnRelease() if exists.
function Gauge:Release()
    return self.OnRelease and self:OnRelease()
end

--- Calls OnUpdate() if unit GUID matches.
-- @param guid (string) Unit GUID.
-- @param ... (tuple) Threat info for unit in form of <unit, threat> pairs.
-- @return boolean - Whether OnUpdate() was called.
function Gauge:Update(guid, ...)
    return guid and guid == self:UnitGUID() and (self:OnUpdate(guid, ...) or true)
end

-- Expose gauge prototype to the public
Timed.Gauge = Gauge
