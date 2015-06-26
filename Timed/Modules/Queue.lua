--------------------------------------------------------------------------------
-- Timed (c) 2011 by Siarkowy <http://siarkowy.net/timed>
-- Released under the terms of BSD 2.0 license.
--------------------------------------------------------------------------------

local Timed = Timed

local UnitGUID = UnitGUID
local UnitName = UnitName
local bit_band = bit.band
local format = format
local pairs, ipairs = pairs, ipairs
local tContains, tinsert, tremove, sort = tContains, tinsert, tremove, sort

local queues    = { } -- threat query queues
local queues_a  = { } -- active queues

Timed.queues    = queues
Timed.queues_a  = queues_a

--
-- UTIL
--

function Timed:QueueBegin(guid)
    tinsert(queues_a, guid)
    sort(queues_a)
end

function Timed:QueueEnd(guid)
    for i, queue in ipairs(queues_a) do
        if queue == guid then
            tremove(queues_a, i)
        end
    end
end

function Timed:QueueGetTime()
    local guid = self.target.guid
    local n = select(2, self:QueueLookupQueue(self.player, guid))
    local num = self:QueueNumPlayers(guid)
    local delay = self.db.profile.queryDelay
    return n * delay / num
end

function Timed:QueueInsert(guid, player)
    tinsert(queues[guid], player)
    if not self:QueueIsActive(guid) then
        self:QueueSort(guid)
    end
end

function Timed:QueueIsActive(guid)
    return tContains(queues_a, guid)
end

function Timed:QueueNumPlayers(guid)
    return queues[guid] and #queues[guid] or 0
end

function Timed:QueueLookup(player)
    local queue, n

    for qid, data in pairs(queues) do
        queue, n = self:QueueLookupQueue(player, qid)
        if queue and n then
            return queue, n
        end
    end
end

function Timed:QueueLookupQueue(player, queue)
    for n, unit in ipairs(queues[queue]) do
        if unit == player then
            return queue, n
        end
    end
end

function Timed:QueueRemove(guid, n)
    tremove(queues[guid], n)
    if not self:QueueIsActive(guid) then
        self:QueueSort(guid)
    end
end

function Timed:QueueShift(guid, player)
    queues[guid] = queues[guid] or { }
    for i, unit in ipairs(queues[guid]) do
        if unit == player then
            tremove(queues[guid], i)
        end
    end
    tinsert(queues[guid], player)
end

function Timed:QueueSort(guid)
    if queues[guid] then
        sort(queues[guid])
    end
end

function Timed:QueueUpdate(guid, sender)
    local queue, n = self:QueueLookup(sender)
    if queue then
        self:QueueRemove(queue, n)
        if #queues[queue] == 0 then
            queues[queue] = nil
        end
    end
    queues[guid] = queues[guid] or { }
    self:QueueInsert(guid, sender)
end

function Timed:TankUpdate()
    self.tank.guid = UnitGUID("targettarget") or UnitGUID("none")
    self.tank.name = UnitName("targettarget") or UnitName("none")
end

function Timed:TargetUpdate()
    self.target.guid = UnitGUID("target") or UnitGUID("none")
    self.target.name = UnitName("target") or UnitName("none")
    self:TriggerEvent("Timed_PlayerTargetChanged")
end

--
-- EVENT HANDLERS
--

local hostileNpcAction = bit.bor(COMBATLOG_OBJECT_TYPE_NPC, COMBATLOG_OBJECT_REACTION_HOSTILE)

function Timed:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName)
    if sourceGUID == self.target.guid and destGUID and bit_band(hostileNpcAction, sourceFlags) then
        if not self:QueueIsActive(sourceGUID) then
            self:QueueBegin(sourceGUID)
            self:BroadcastQueueBegin(sourceGUID)
            self:SheduleQueryThreat()
        end
    elseif event == "UNIT_DIED" then
        if self:QueueIsActive(destGUID) then
            self:QueueEnd(destGUID)
            self:BroadcastQueueEnd(destGUID)
            self:ThreatClear(destGUID)
        end
    end
end

function Timed:UNIT_TARGET(unit)
    if unit == "player" then
        self:TargetUpdate()
        local tguid = self.target.guid
        self:TimerDisable()
        self:TimerReset()
        self:QueueUpdate(tguid, self.player)
        self:BroadcastQueueJoin(tguid)
        if self:QueueIsActive(tguid) then
            self:SheduleQueryThreat()
        end
        self:TankUpdate()
    elseif unit == "target" then
        self:TankUpdate()
    end
end

--
-- COMM HANDLERS
--

function Timed:BroadcastQueueBegin(guid)
    self:SendCommMessage("GROUP", "QUEUE_BEGIN", self.util.compress(guid))
end

function Timed:BroadcastQueueEnd(guid)
    self:SendCommMessage("GROUP", "QUEUE_END", self.util.compress(guid))
end

function Timed:BroadcastQueueJoin(guid)
    self:SendCommMessage("GROUP", "QUEUE_JOIN", self.util.compress(guid))
end

function Timed.OnCommReceive:QUEUE_BEGIN(prefix, sender, distribution, guid)
    guid = self.util.decompress(guid)
    if not self:QueueIsActive(guid) then
        self:QueueBegin(guid)
    end
end

function Timed.OnCommReceive:QUEUE_END(prefix, sender, distribution, guid)
    self:QueueEnd(self.util.decompress(guid))
end

function Timed.OnCommReceive:QUEUE_JOIN(prefix, sender, distribution, guid)
    self:QueueUpdate(self.util.decompress(guid), sender)
end
