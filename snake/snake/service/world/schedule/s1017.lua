--import module
local global  = require "global"

local schedulebase=import(service_path("schedule/scheduleobj"))


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

function CSchedule:GetMaxTimes()
    local oWorldMgr = global.oWorldMgr
    local oHuodongMgr = global.oHuodongMgr
    local oHDObj=oHuodongMgr:GetHuodong("shootcraps")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer and oHDObj then
        return oHDObj:MaxTime(oPlayer) + oHDObj:GetGoldCoinMaxCnt()
    end
    return super(CSchedule).GetMaxTimes(self)
end