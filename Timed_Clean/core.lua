--------------------------------------------------------------------------------
-- Timed Clean (c) 2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

TIMED_CLEAN = "Timed Clean"

TimedClean = LibStub("AceAddon-3.0"):NewAddon(
    {
        author      = GetAddOnMetadata(TIMED_CLEAN:gsub(' ', '_'), "Author"),
        version     = GetAddOnMetadata(TIMED_CLEAN:gsub(' ', '_'), "Version"),
    },

    TIMED_CLEAN,

    -- embeds
    "AceEvent-3.0",
    "AceConsole-3.0"
)

-- Upvalues --------------------------------------------------------------------

local Timed = Timed
local Clean = TimedClean
local Gauge = Timed.Gauge
local UnitInMeleeRange = Timed.UnitInMeleeRange
local shorten = Timed.shorten

local TIMED_PULLAGGRO   = TIMED_PULLAGGRO
local TIMED_OVERAGGRO   = TIMED_OVERAGGRO
local TIMED_TANKING     = TIMED_TANKING
local TIMED_INSECURE    = TIMED_INSECURE
local TIMED_SAFE        = TIMED_SAFE
local PLAYER            = UnitName("player")

local frames = { }
local gt = GameTooltip

-- Core ------------------------------------------------------------------------

local function GetSituation(ratio)
    if ratio > 1.0 then
        return TIMED_OVERAGGRO
    -- elseif ratio == 1.0 then
        -- return TIMED_TANKING
    elseif ratio > Timed.db.profile.threshold then
        return TIMED_INSECURE
    else
        return TIMED_SAFE
    end
end

function Clean:CreateGaugeFrame(gid, displayName)
    local height = self.db.profile.barheight
    local margin = self.db.profile.barmargin

    local name = format("TimedClean%sGaugeFrame", gsub(gid, "^.", string.upper))
    local fr = CreateFrame("Frame", name, UIParent)

    fr:SetMovable(true)
    fr:SetClampedToScreen(true)
    fr:EnableMouse(true)
    fr:RegisterForDrag("LeftButton")
    fr:SetScript("OnDragStart", fr.StartMoving)
    fr:SetScript("OnDragStop", fr.StopMovingOrSizing)
    fr:SetScript("OnEnter", function(self) self.gauge:OnEnter() end)
    fr:SetScript("OnLeave", function(self) self.gauge:OnLeave() end)
    fr:SetScale(self.db.profile.fscale)

    fr:SetPoint("CENTER")
    fr:SetWidth(self.db.profile.fwidth)
    fr:SetHeight(26 + 2 * self.db.profile.backdrop.insets.top + 5 * height + 4 * margin)

    fr:SetBackdrop(self.db.profile.backdrop)
    fr:SetBackdropColor(0, 0, 0, 0.5)
    fr:SetBackdropBorderColor(.5, .5, .5, 1)

    -- queue info
    local num = fr:CreateFontString(fr:GetName() .. "Num")
    num:SetFontObject(GameFontHighlight)
    num:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -8, -8)
    num:SetPoint("BOTTOMRIGHT", fr, "TOPRIGHT", -8, -18)
    num:SetFormattedText(self.db.profile.queformat, 0, 10)
    fr.num = num

    -- unit name
    local unit = fr:CreateFontString(fr:GetName() .. "Name")
    unit:SetFontObject(GameFontHighlight)
    unit:SetPoint("TOPLEFT", fr, "TOPLEFT", 8, -8)
    unit:SetPoint("BOTTOMRIGHT", num, "BOTTOMLEFT")
    unit:SetJustifyH("LEFT")
    unit:SetText(displayName or TIMED)
    fr.unit = unit

    fr.bars = { }
    local pad = 8 -- initial padding

    for id = 0, 4 do
        -- bar frame
        local bar = CreateFrame("StatusBar", fr:GetName().."Bar"..id, fr)
        bar:SetMinMaxValues(0, 1)
        bar:SetPoint("TOPLEFT", unit, "BOTTOMLEFT", 0, -pad)
        bar:SetPoint("BOTTOMRIGHT", num, "BOTTOMRIGHT", 0, -pad -height)
        bar:SetStatusBarTexture(self.db.profile.barstyle)
        bar:SetStatusBarColor(1, 0, 0)
        bar:SetValue(1 - id)
        pad = pad + height + margin

        -- threat value
        local thr = bar:CreateFontString(bar:GetName() .. "Threat", "ARTWORK")
        thr:SetFontObject(GameFontNormal)
        thr:SetText(id == 0 and UNKNOWN or "")
        thr:SetPoint("RIGHT", bar, "RIGHT", -1, 1)
        local col = self.db.profile.colors.threat
        thr:SetTextColor(col.r, col.g, col.b)
        bar.threat = thr

        -- unit name
        local unit = bar:CreateFontString(bar:GetName() .. "Name", "ARTWORK")
        unit:SetFontObject(GameFontNormal)
        unit:SetText(id == 0 and TIMED_PULLAGGRO_T or "")
        local col = self.db.profile.colors.unit
        unit:SetTextColor(col.r, col.g, col.b)
        unit:SetPoint("LEFT", bar, "LEFT", 1, 1)
        unit:SetPoint("RIGHT", thr, "LEFT")
        unit:SetJustifyH("LEFT")
        bar.unit = unit

        fr.bars[id] = bar
    end

    frames[gid] = fr
    return fr
end

--[[
function Clean:RedrawGauges(full)
    for gid, gauge in pairs(Timed.gauges) do
        gauge:Redraw(full)
    end
end
--]]

function Clean:GetGaugeFrame(gauge)
    local gid = gauge:UnitToken()
    local name = gauge:UnitName()

    local frame = frames[gid:gsub("^.", string.upper)] or self:CreateGaugeFrame(gid, name)
    frame.gauge = gauge

    return frame
end

function Clean:GetVersionNumber()
    return Timed.GetVersionNumber(self)
end

-- Gauge overrides -------------------------------------------------------------

--- Initialize handler.
function Gauge:OnInitialize()
    self.frame = Clean:GetGaugeFrame(self)
    self.bars = self.frame.bars
    self:OnUpdate()
end

--- Data update handler.
function Gauge:OnUpdate(guid, ...)
    local time = GetTime()
    self.timeDiff = self.time and time - self.time or 0
    self.time = time

    local unit, threat, ratio
    local melee = UnitInMeleeRange(self:UnitToken())
    local factor = not melee and 1.3 or 1.1
    local pullaggro = select(2, ...)

    if not pullaggro then
        return
    end

    pullaggro = pullaggro * factor

    -- update pull aggro value
    self.bars[0].threat:SetFormattedText(Clean.db.profile.thrformat:gsub("%%.?$?#",
        shorten(pullaggro)), pullaggro, factor*100)

    for i = 1, 4 do
        local bar = self.bars[i]

        unit, threat = select(i * 2 - 1, ...)
        threat = tonumber(threat)

        if not unit then
            if bar:IsShown() then bar:Hide() end
        else
            ratio = threat/pullaggro
            bar.unit:SetText(unit)
            bar.threat:SetFormattedText(Clean.db.profile.thrformat:gsub("%%.?$?#",
                shorten(threat)), threat, ratio*100)
            bar:SetValue(ratio)
            local col = Clean.db.profile.colors[GetSituation(ratio)]
            bar:SetStatusBarColor(col.r, col.g, col.b, col.a)
            if not bar:IsShown() then bar:Show() end
        end
    end

    if gt:IsOwned(self.frame) then
        self:OnEnter()
    end
end

--- Mouse enter handler.
function Gauge:OnEnter()
    gt:ClearLines()
    gt:SetOwner(self.frame, "ANCHOR_CURSOR")
    gt:AddLine(self:UnitName() or NONE)
    gt:AddDoubleLine("Unit", self:UnitToken() or "Fixed", 1, 1, 1, 1, 1, 1, 1)
    gt:AddLine("\nQueue info")
    gt:AddDoubleLine("Players", Timed:GetQueueCount(self:UnitGUID()), 1, 1, 1, 1, 1, 1)
    gt:AddDoubleLine("Nominal", format("%.2f s", self:GetNominalInterval()), 1, 1, 1, 1, 1, 1)
    gt:AddDoubleLine("Effective", format("%.2f s", self.timeDiff or 0), 1, 1, 1, 1, 1, 1)
    gt:Show()
end

--- Mouse leave handler.
function Gauge:OnLeave()
    gt:SetOwner(UIParent)
    gt:Hide()
end

--- Gauge release handler.
function Gauge:OnRelease()
    -- dispose gauge frame
    local frame = self.frame
    frame:SetUserPlaced(false)
    frame:Hide()

    -- wipe user data
    for k, _ in pairs(self) do self[k] = nil end
end

function Gauge:GetNominalInterval()
    local count = Timed:GetQueueCount(self:UnitGUID())
    return count > 0 and Timed:GetQueryInterval() / count or 0
end

-- Initialization --------------------------------------------------------------

local defaults = {
    profile = {
        backdrop = {
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        },
        barheight = 16,
        barmargin = 1,
        barstyle = "Interface\\Addons\\SharedMedia\\statusbar\\Minimalist",
        colors = {
            -- bars
            [TIMED_PULLAGGRO]   = { r = 1, g = 0, b = .2, a = 1 },      -- pull aggro
            [TIMED_TANKING]     = { r = 1, g = .5, b = .2, a = 1 },     -- tanking
            [TIMED_OVERAGGRO]   = { r = 1, g = .2, b = .2, a = 1 },     -- overaggro
            [TIMED_INSECURE]    = { r = 1, g = 1, b = .2, a = 3/4 },    -- insecure
            [TIMED_SAFE]        = { r = .2, g = 1, b = .2, a = 1/4 },   -- safe

            -- labels
            threat  = { r = 1, g = 1, b = 1 },
            unit    = { r = 1, g = 1, b = 1 },
        },
        fscale = 1, -- frame scale
        fwidth = 200, -- frame width
        thrformat = "%#", -- threat number format, %# stands for shortened float
        queformat = "%2$.1f s", -- queue info format
    }
}

function Clean:OnInitialize()
    -- initialize database
    self.db = LibStub("AceDB-3.0"):New("TimedCleanDB", defaults, "Default")
end
