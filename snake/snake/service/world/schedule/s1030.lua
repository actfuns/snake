--import module
local global  = require "global"

local schedulebase=import(service_path("schedule/scheduleobj"))

-- 跑环
function NewSchedule(id)
    return CSchedule:New(id)
end

CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule,schedulebase.CSchedule)

function CSchedule:New(scheduleid)
    local o = super(CSchedule).New(self,scheduleid)
    return o
end

function CSchedule:GetDoneTimes()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iDoneTime = 0
    if oPlayer then
        iDoneTime = global.oRunRingMgr:AccpetTimes(oPlayer)
    end
    return iDoneTime
end

function CSchedule:GetMaxTimes()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        return global.oRunRingMgr:MaxWeekAcceptTimes(oPlayer)
    end
    return super(CSchedule).GetMaxTimes(self)
end
