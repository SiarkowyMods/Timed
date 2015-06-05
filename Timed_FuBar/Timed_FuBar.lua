--------------------------------------------------------------------------------
-- Timed (c) 2011 by Siarkowy <http://siarkowy.net/timed>
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed
local Fu = Timed:NewModule("Timed", "AceEvent-2.0", "FuBarPlugin-2.0")
local tablet = AceLibrary("Tablet-2.0")

Fu.title                    = "Timed"
Fu.clickableTooltip         = false
Fu.defaultMinimapPosition   = 220
Fu.hasIcon                  = [[Interface\Icons\Ability_DualWieldSpecialization]]
Fu.hasNoColor               = true

local floor     = floor
local format    = format
local max       = max
local pairs     = pairs
local tconcat   = table.concat
local tinsert   = tinsert

local AGGRO_WARN_THRESHOLD = 90
local CHECK_TEX = [[Interface\Icons\Ability_DualWield]]

local warned

function Fu:OnInitialize()
    self.db = Timed:AcquireDBNamespace("Fu")
    Timed:RegisterDefaults("Fu", "profile", { AggroWarning = true })
end

local func = function() Fu:Update() end

function Fu:OnEnable()
    self:RegisterEvent("Timed_OnThreatUpdate", func)
    self:RegisterEvent("Timed_PlayerTargetChanged", func)
end

local function GetColor(p)
    if p >= 100 then
        return 1, .2, .2
    elseif p >= 75 then
        return 1, .5, .2
    elseif p >= 50 then
        return 1, 1, .2
    else
        return .2, 1, .2
    end
end

local function UnitInMeleeRange(unitID) -- from Threat-2.0
    return UnitExists(unitID) and UnitIsVisible(unitID) and CheckInteractDistance(unitID, 3)
end

function Fu:Warn(msg)
    CombatText_AddMessage(msg, CombatText_StandardScroll, 1, 0, 0,  'crit', false)
end

function Fu:OnTooltipUpdate()
    local tguid = Timed.target.guid
    local threat = Timed.threat[tguid]
    if not threat or not UnitExists("target") or UnitIsDead("target") then return end

    local cat

    local size = Timed:QueueNumPlayers(tguid)
    local delay = Timed.db.profile.queryDelay

    cat = tablet:AddCategory(
        'text',     (UnitName("target")),
        'columns',  2
    )

    cat:AddLine('text', 'Queue size', 'text2', format("%d |4player:players;", size))
    cat:AddLine('text', 'Interval', 'text2', format("%.2f s", delay / size))

    cat = tablet:AddCategory(
        'text',     '#',
        'text2',    'Unit',
        'text3',    'Threat',
        'text4',    '%',
        'justify',  'right',
        'columns',  4
    )

    local tankaggro =
        threat[1][3] and threat[1][2] or
        threat[2][3] and threat[2][2] or
        threat[3][3] and threat[3][2] or
        threat[4][3] and threat[4][2]

    if not tankaggro then
        tankaggro = threat[1][2]
        warned = true
    end

    local multiplier

    if UnitInMeleeRange("target") then
        multiplier = 1.1
    else
        multiplier = 1.3
    end

    local pullaggro = tankaggro * multiplier

    cat:AddLine(
        'text',     0,
        'text2',    'Pull aggro',
        'text3',    format("%.2f", pullaggro),
        'text4',    format("%d", multiplier * 100),
        'justify',  'right',
        'justify2', 'left',
        'justify3', 'right',
        'justify4', 'right',
        'hasCheck', true,
        'checked',  false
    )

    for k, d in pairs(threat) do
        local player = d[1]
        if player then
            local percent = max(floor(d[2] / tankaggro * 100 + 0.5), 0)
            local r, g, b = GetColor(percent)
            local c = format("%02x%02x%02x", r * 255, g * 255, b * 255)
            cat:AddLine(
                'text',     format("|cff%s%d|r", c, k),
                'text2',    format("|cff%s%s|r", c, player),
                'text3',    format("|cff%s%.2f|r", c, d[2]),
                'text4',    format("|cff%s%d|r", c, tankaggro > 0 and percent or 0),
                'justify',  "right",
                'justify2', "left",
                'justify3', "right",
                'justify4', "right",
                'hasCheck', true,
                'checked',  d[3],
                'checkIcon', CHECK_TEX
            )

            if Timed.db.profile.AggroWarning and player == self.player then
                if not warned and not d[3] and tankaggro > 0 and percent >= AGGRO_WARN_THRESHOLD then
                    self:Warn(format("You have passed %d%% aggro!", AGGRO_WARN_THRESHOLD))
                    warned = true
                elseif percent < AGGRO_WARN_THRESHOLD then
                    warned = nil
                end
            end
        end
    end
end

Fu.OnMenuRequest = {
    handler = Fu,
    type = "group",
    args = {
        versions = {
            name = "Roster versions",
            desc = "Prints reported addon versions to chat frame",
            type = "execute",
            func = function()
                Timed:ListVersions()
            end,
            order = 1
        },
        warnings = {
            name = "Toggle aggro warnings",
            desc = "Enable/disable aggro warnings",
            type = "toggle",
            get = function()
                return Fu.db.profile.AggroWarning
            end,
            set = function(v)
                Fu.db.profile.AggroWarning = v
            end,
            order = 2
        },
        inRaidOnly = {
            name = "In raid instances only",
            desc = "Select whether perform only in raid instances or the entire world",
            type = "toggle",
            get = function()
                return Timed.db.profile.inRaidOnly
            end,
            set = function(v)
                Timed.db.profile.inRaidOnly = v
            end,
            order = 3
        },
    }
}
