--------------------------------------------------------------------------------
-- Timed (c) 2011, 2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

-- Upvalues --------------------------------------------------------------------

local assert        = assert
local pairs         = pairs
local rawget        = rawget
local shorten       = Timed.shorten
local UnitExists    = UnitExists
local UnitGUID      = UnitGUID
local UnitInMeleeRange = Timed.UnitInMeleeRange
local UnitName      = UnitName

-- Threat gauge object stuff ---------------------------------------------------

--- Prototype object
local Gauge = { }
Gauge.__meta = { __index = Gauge }

--- Creates new gauge object and initializes it.
-- @param unit (string) Unit ID for new gauge.
-- @param const (boolean) Whether to calculate parameters only once.
-- @return table The gauge object.
function Gauge:New(unit, const)
    assert(unit, "No unit specified to Gauge:New().")
    assert(not const or UnitExists(unit), format("Unit %s does not exist.", unit))

    local gauge = setmetatable({
        unit = not const and unit or nil, -- unit ID if variable
        guid = const and UnitGUID(unit) or nil, -- GUID if const
        name = const and UnitName(unit) or nil, -- unit name if const
    }, self.__meta)

    gauge:Init()

    return gauge
end

--- Initializes the object. Called internally by :Init().
-- This should be overwritten or hooked if desired.
function Gauge:OnInitialize()
    -- self:Print("Gauge %s initialized.", self:UnitToken())
end

--- Clears user data. Called internally by :Release().
-- This should be overwritten or hooked if desired.
function Gauge:OnRelease()
    -- self:Print("Gauge %s released.", self:UnitToken())
    for k, _ in pairs(self) do self[k] = nil end
end

--- Handles updated threat data. Called internally by Update.
-- This should be overwritten or hooked if desired.
function Gauge:OnUpdate(guid, ...)
    if not Timed.db.profile.autodump then return end

    local unit, threat, ratio
    local pullaggro = select(2, ...) * (not UnitInMeleeRange(self:UnitToken())
        and 1.3 or 1.1)

    Timed:Printf("Threat info for %s", self:UnitName())
    for i = 1, select("#", ...), 2 do
        unit, threat = select(i, ...)
        ratio = threat/pullaggro
        self:Print("%s %s %s (%d%%)", strrep("||", ratio * 10), unit, shorten(threat), ratio * 100)
    end
end

--- Prints formatted data to chat frame.
-- @param f Message format.
-- @param ... Argument list to format.
function Gauge:Print(f, ...)
    DEFAULT_CHAT_FRAME:AddMessage(format(f, ...))
end

--- Returns unit GUID of the gauge.
-- @return string|nil Unit GUID.
function Gauge:UnitGUID()
    return self.guid or UnitGUID(self.unit)
end

--- Returns unit name of the gauge.
-- @return string|nil Unit name.
function Gauge:UnitName()
    return self.name or UnitName(self.unit)
end

function Gauge:UnitToken()
    return self.unit or self.guid
end

--- Calls :OnInitialize() if exists.
function Gauge:Init()
    return self.OnInitialize and self:OnInitialize()
end

--- Calls :OnRelease() if exists.
function Gauge:Release()
    return self.OnRelease and self:OnRelease()
end

--- Calls OnUpdate on appropriate unit GUID.
-- @param guid Unit GUID.
-- @param ... Threat info for unit.
-- @return boolean :OnUpdate() called flag.
function Gauge:Update(guid, ...)
    if guid and guid == self:UnitGUID() then
        self:OnUpdate(guid, ...)
        return true
    end

    return nil
end

-- Expose gauge prototype to the public
Timed.Gauge = Gauge
