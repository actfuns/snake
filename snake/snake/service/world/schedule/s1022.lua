local global  = require "global"
local schedulebase = import(service_path("schedule/scheduleobj"))

function NewSchedule(id)
    return CSchedule:New(id)
end

CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule, schedulebase.CSchedule)

function CSchedule:GetDoneTimes()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iDoneCnt = 0
    if oPlayer then
        iDoneCnt = oPlayer.m_oWeekMorning:Query("lingxi_donecnt", 0)
    end
    return iDoneCnt
end
