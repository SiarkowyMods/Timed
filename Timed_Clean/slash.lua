--------------------------------------------------------------------------------
-- Timed Clean (c) 2013 by Siarkowy
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed
local Clean = TimedClean
local Media = LibStub("LibSharedMedia-3.0")

local TIMED_PULLAGGRO   = TIMED_PULLAGGRO
local TIMED_OVERAGGRO   = TIMED_OVERAGGRO
local TIMED_TANKING     = TIMED_TANKING
local TIMED_INSECURE    = TIMED_INSECURE
local TIMED_SAFE        = TIMED_SAFE

-- Borrowed from Omen2
local function GetLSMIndex(t, value)
	for k, v in pairs(Media:List(t)) do
		if v == value then
			return k
		end
	end

	return nil
end

Clean.slash = {
    name = "Clean",
    desc = "Timed Clean settings.",
    handler = Clean,
    type = "group",
    guiHidden = true,
    guiInline = true,
    cmdInline = false,
    args = {
        -- General

        general = {
            name = "Gauge",
            type = "header",
            cmdHidden = true,
            order = 5
        },
        scale = {
            name = "Scale",
            type = "range",
            min = 0.1,
            max = 3,
            step = 0.1,
            isPercent = true,
            get = function(info)
                return Clean.db.profile.fscale
            end,
            set = function(info, v)
                Clean.db.profile.fscale = v
                Clean:Redraw()
            end,
            order = 10
        },
        width = {
            name = "Width",
            type = "range",
            min = 50,
            max = 1000,
            step = 1,
            get = function(info)
                return Clean.db.profile.fwidth
            end,
            set = function(info, v)
                Clean.db.profile.fwidth = v
                Clean:Redraw()
            end,
            order = 15
        },
        barstyle = {
            name = "Bar style",
            type = "select",
            dialogControl = "LSM30_Statusbar",
            values = Media:List("statusbar"),
            get = function(info)
                return GetLSMIndex("statusbar", Clean.db.profile.barstyle)
            end,
            set = function(info, v)
                Clean.db.profile.barstyle = Media:List("statusbar")[v]
                Clean:Redraw()
            end,
            order = 20
        },
        borderstyle = {
            name = "Border",
            type = "select",
            dialogControl = "LSM30_Border",
            values = Media:List("border"),
            get = function(info)
                return GetLSMIndex("border", Clean.db.profile.borderstyle)
            end,
            set = function(info, v)
                local db = Clean.db.profile
                db.borderstyle = Media:List("border")[v]
                db.backdrop.edgeFile = Media:Fetch("border", db.borderstyle)
                Clean:Redraw()
            end,
            order = 25
        },
        bgcolor = {
            name = "Background color",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.bgcolor
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.bgcolor
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 30
        },
        bordercolor = {
            name = "Border color",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.bordercolor
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.bordercolor
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 35
        },

        -- Threat situation coloring

        situations = {
            name = "Threat situation",
            type = "header",
            cmdHidden = true,
            order = 50
        },
        pullaggrocolor = {
            name = "Pull aggro",
            desc = "Pull aggro coloring.",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.colors[TIMED_PULLAGGRO]
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.colors[TIMED_PULLAGGRO]
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 55
        },
        overaggrocolor = {
            name = "Overaggro",
            desc = "Overaggro coloring.",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.colors[TIMED_OVERAGGRO]
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.colors[TIMED_OVERAGGRO]
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 60
        },
        insecurecocolor = {
            name = "Insecure",
            desc = "Insecure aggro coloring.",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.colors[TIMED_INSECURE]
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.colors[TIMED_INSECURE]
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 65
        },
        safecolor = {
            name = "Safe",
            desc = "Safe aggro coloring.",
            type = "color",
            hasAlpha = true,
            get = function(info)
                local col = Clean.db.profile.colors[TIMED_SAFE]
                return col.r, col.g, col.b, col.a
            end,
            set = function(info, r, g, b, a)
                local col = Clean.db.profile.colors[TIMED_SAFE]
                col.r, col.g, col.b, col.a = r, g, b, a
                Clean:Redraw()
            end,
            order = 70
        },
    }
}

Timed.slash.args.clean = Clean.slash
