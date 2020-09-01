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

function CSchedule:GetDoneTimes()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iDoneTime = 0
    if oPlayer then
        iDoneTime = oPlayer.m_oThisWeek:Query("orgtask_finish",0)
    end
    return iDoneTime
end
