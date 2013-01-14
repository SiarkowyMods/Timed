--
-- ACE ADDON PROLOG
--

Timed = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDB-2.0", "AceModuleCore-2.0", "AceConsole-2.0", "AceComm-2.0")

local Timed = Timed

Timed.OnCommReceive = { }

function Timed:OnInitialize()
	self.player = ( UnitName("player") )
	
	-- database stuff
	self:RegisterDB("TimedDB")
	self:RegisterDefaults("profile", {
		debug = nil,
		inRaidOnly = true,
		queryDelay = 10,
		queryMessage = ".debug threatlist",
	})
	
	self.lastQueryTime = 0
	
	-- data banks
	self.guids 		= { } -- GUID table
	self.tank		= { } -- tank data
	self.target		= { } -- target data
	self.threat 	= { } -- threat data
	self.versions 	= { } -- roster addon versions
	
	-- versioning
	self:RegisterVersion(self.player, self.version)
	
	-- comm
	self.commPrefix = "TMD"
	self:SetCommPrefix(self.commPrefix)
	self:RegisterMemoizations{
		-- Core
		"THREAT",
		"COOLDOWN",
		-- Queue
		"QUEUE_BEGIN",
		"QUEUE_END",
		"QUEUE_JOIN",
		-- Hello
		"HELLO",
		"HELLO_REPLY",
		-- GUIDs
		"GUID_QUERY",
		"GUID_PRESENT",
		"GUID_EXPLAIN",
		"GUID_EXPLANATION",
	}
end

function Timed:OnEnable()
	-- register events
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_TARGET")
	self:RegisterEvent("Timed_OnTimer") -- timer ready
	-- enable comm
	self:RegisterComm(self.commPrefix, "GROUP", "OnCommReceive")
	self:RegisterComm(self.commPrefix, "WHISPER", "OnCommReceive")
	-- update and broadcast target
	self:TargetUpdate()
	self:TankUpdate()
	self:PARTY_MEMBERS_CHANGED()
	self:BroadcastQueueJoin(self.target.guid)
end

function Timed:PLAYER_ENTERING_WORLD()
	self.raid = ( select(2, IsInInstance()) == "raid" )
end

--
-- UTIL
--

do
	local pairs = pairs
	local type = type
	
	local function wipe(t)
		for k, _ in pairs(t) do
			if type(t[k]) == "table" then
				wipe(t[k])
			end
			t[k] = nil
		end
		t = nil
	end
	Timed.util = Timed.util or { }
	Timed.util.wipe = wipe
end