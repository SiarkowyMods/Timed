local Timed = Timed

local tinsert = tinsert
local sort = sort
local GetNumRaidMembers = GetNumRaidMembers
local GetTime = GetTime

local MINIMUM_QUERY_DELAY = 0.5

--
-- UTIL
--

function Timed:OnThreatUpdate()
    self:TriggerEvent("Timed_OnThreatUpdate")
end

function Timed:QueryThreatInfo()
    if self.db.profile.inRaidOnly and not self.raid then return end
    local time = GetTime()
    local delta = time - self.lastQueryTime
    local check = delta <= self.db.profile.queryDelay

    if check then
        self:SheduleQueryThreat()
        return
    end
    if UnitExists("target") and not UnitIsDead("target") and not UnitIsFriend("player", "target") then
        self:QueueShift(self.target.guid, self.player)
        self:SheduleQueryThreat()
        self.lastQueryTime = time
        SendChatMessage(self.db.profile.queryMessage, "GUILD")
        return true
    end
end

function Timed:ThreatAdd(guid, pos, unit, threat, isTank)
    if pos > 4 then return end

    local d = self.threat[guid][pos]

    d[1] = unit
    d[2] = threat
    d[3] = isTank
end

function Timed:ThreatClear(guid)
    if not self.threat[guid] then return end
    self.util.wipe(self.threat[guid])
    self.threat[guid] = nil
end

function Timed:ThreatReset(guid)
    self.threat[guid] = self.threat[guid] or { { }, { }, { }, { } }

    local t = self.threat[guid]
    for i = 1, 4 do
        t[i][1] = false
        t[i][2] = -1
        t[i][3] = false
    end
end

local function threatSort(a, b)
    return a[2] > b[2]
end

function Timed:ThreatSort(guid)
    if self.threat[guid] then
        sort(self.threat[guid], threatSort)
    end
end

--
-- EVENT HANDLERS
--

function Timed:Timed_OnTimer()
    self:QueryThreatInfo()
end

--
-- COMM HANDLERS
--

function Timed:BroadcastThreat(guid, data)
    local tankId = data[1][3] and 1 or data[2][3] and 2 or data[3][3] and 3 or data[4][3] and 4 or 0
    self:SendCommMessage("GROUP", "THREAT", guid, tankId, data[1][1], data[1][2], data[2][1], data[2][2], data[3][1], data[3][2], data[4][1], data[4][2])
end

function Timed.OnCommReceive:THREAT(prefix, sender, distribution, guid, tankId, u1, t1, u2, t2, u3, t3, u4, t4)
    self.threat[guid] = self.threat[guid] or { { }, { }, { }, { } }

    local t = self.threat[guid]

    t[1][1] = u1
    t[1][2] = t1
    t[1][3] = (tankId == 1)

    t[2][1] = u2
    t[2][2] = t2
    t[2][3] = (tankId == 2)

    t[3][1] = u3
    t[3][2] = t3
    t[3][3] = (tankId == 3)

    t[4][1] = u4
    t[4][2] = t4
    t[4][3] = (tankId == 4)

    self:ThreatSort(guid)
    self:QueueShift(guid, sender)
    if guid == self.target.guid then
        self:TimerSet( self:QueueGetTime() )
    end
    self:OnThreatUpdate()
end
