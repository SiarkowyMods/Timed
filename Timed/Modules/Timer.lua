local Timed = Timed

local SHEDULE_DELAY = 0.03

-- Timing frame init
local TimerFrame
TimerFrame = CreateFrame("frame")
TimerFrame:Hide()

local timer = 0

local function TimerOnUpdate(self, elapsed)
	timer = timer - elapsed
	
	if timer > 0 then return end
	
	TimerFrame:Hide()
	timer = 0
	
	Timed:TriggerEvent("Timed_OnTimer")
end

TimerFrame:SetScript("OnUpdate", TimerOnUpdate)

function Timed:SheduleQueryThreat()
	local time = self:QueueGetTime()
	self:TimerSet(time + SHEDULE_DELAY)
	self:TimerEnable()
end

function Timed:TimerToggleActive(v)
	if v then
		TimerFrame:Show()
	else
		TimerFrame:Hide()
	end
end

function Timed:TimerDisable()
	TimerFrame:Hide()
end

function Timed:TimerEnable()
	TimerFrame:Show()
end

function Timed:TimerIsActive()
	return TimerFrame:IsShown()
end

function Timed:TimerReset()
	self:TimerSet(0)
end

function Timed:TimerSet(v)
	timer = tonumber(v) or 0
end