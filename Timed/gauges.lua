--------------------------------------------------------------------------------
-- Timed (c) 2011-2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

-- Gauge management functions --------------------------------------------------

local gauges = Timed.gauges

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
