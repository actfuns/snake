local global = require "global"

local schedulebase = import(service_path("schedule/scheduleobj"))

function NewSchedule(id)
    return CSchedule:New(id)
end

CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule, schedulebase.CSchedule)

function CSchedule:New(scheduleid)
    local o = super(CSchedule).New(self, scheduleid)
    return o
end

function CSchedule:GetDoneTimes()
    local oHuodong = global.oHuodongMgr:GetHuodong("festivalgift")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iDoneTime = 0
    if oHuodong and oPlayer then
        local bIsFestival, iText = oHuodong:ValidGetFestivalGift(oPlayer)
        if not bIsFestival then
            iDoneTime = 1
        end
    end
    return iDoneTime
end