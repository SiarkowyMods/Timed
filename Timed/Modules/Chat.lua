--------------------------------------------------------------------------------
-- Timed (c) 2011 by Siarkowy <http://siarkowy.net/timed>
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

function Timed.ChatFilter(msg)
    if Timed.filter then
        return true
    end

    return false, msg
end

function Timed:FilterSystemMessages(state)
    if state then
        self.filter = true
        return
    end

    self.filterToggle = true
end

function Timed:CHAT_MSG_SYSTEM(msg)
    if self.filterToggle then
        self.filter = not self.filter
        self.filterToggle = false
    end

    local tguid = self.target.guid

    if msg:match("Threat list of") then
        self:ThreatReset(tguid)
        self:FilterSystemMessages(true)
        return
    end

    if msg:match("End of threat list.") then
        self:ThreatSort(tguid)
        self:BroadcastThreat(tguid, self.threat[tguid])
        self:FilterSystemMessages(false)
        self:OnThreatUpdate()
        return
    end

    local pos, unit, threat = msg:match("(%d+)\.%s+(.-)%s+[(]guid .+[)]%s+\-%s+threat%s+(.+)%s*")

    if unit and threat then
        self:ThreatAdd(tguid, tonumber(pos), unit, tonumber(threat) or 0, (unit == self.tank.name))
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Timed.ChatFilter)
