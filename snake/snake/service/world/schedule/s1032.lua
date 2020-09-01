--import module
local global = require "global"
local schedulebase=import(service_path("schedule/scheduleobj"))


function NewSchedule(id)
    return CSchedule:New(id)
end

CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule,schedulebase.CSchedule)

function CSchedule:GetDoneTimes()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return 0 end

    local iFuben = self:GetFubenId()
    local oProgress = oPlayer.m_oBaseCtrl.m_oFubenMgr
    if oProgress:GetFubenRewardCnt(iFuben) >= 5 then
        return 1
    end
    return 0
end

function CSchedule:GetFubenId()
    return 20001
end

function CSchedule:NeedResetWeekly()
    return true
end

function CSchedule:NeedResetDaily()
    return false
end
