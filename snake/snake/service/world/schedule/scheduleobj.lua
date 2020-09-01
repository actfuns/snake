--import module
local global  = require "global"
local res = require "base.res"
local statistics = require "public.statistics"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewSchedule(id)
    return CSchedule:New(id)
end


CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule,datactrl.CDataCtrl)

function CSchedule:New(scheduleid)
    local o = super(CSchedule).New(self)
    o:SetData("id", scheduleid)
    o:Init()
    return o
end

function CSchedule:Init(pid)
    self:SetInfo("pid",pid)
end

function CSchedule:GetScheduleInfo()
    local iScheduleId = self:GetData("id")
    local mInfo = res["daobiao"]["schedule"]["schedule"][iScheduleId]
    assert(mInfo, string.format("get schedule info err %s", iScheduleId))
    return mInfo
end

function CSchedule:Load(mData)
    local mData = mData or {}
    self:SetData("id", mData.id)
    self:SetData("donetimes", mData.donetimes)
    self:SetData("activepoint", mData.activepoint)
end

function CSchedule:Save()
    local mData = {}
    mData.id = self:GetData("id")
    mData.donetimes = self:GetData("donetimes")
    mData.activepoint = self:GetData("activepoint")
    return mData
end

function CSchedule:ID()
    return self:GetData("id")
end

function CSchedule:Type()
    return self:GetScheduleInfo()["type"]
end

function CSchedule:GetMaxTimes()
    return self:GetScheduleInfo()["maxtimes"] or 0
end

function CSchedule:GetMaxPoints()
    return self:GetScheduleInfo()["maxpoint"] or 0
end

function CSchedule:GetPerPoints()
    return self:GetScheduleInfo()["perpoint"] or 0
end

function CSchedule:GetDoneTimes()
    return self:GetData("donetimes", 0)
end

function CSchedule:AddDoneTimes()
    local iMaxTimes = self:GetMaxTimes()
    if iMaxTimes ~= -1 and self:GetDoneTimes() >= iMaxTimes then
        return
    end
    self:SetData("donetimes", self:GetData("donetimes", 0) + 1)
end

function CSchedule:GetActivePoint()
    return self:GetData("activepoint", 0)
end

function CSchedule:AddActivePoint()
    if self:GetActivePoint() >= self:GetMaxPoints() then
        return 0
    end
    local iPerPoint = self:GetPerPoints()
    if iPerPoint == 0 then
        return 0
    end
    local iPoint = math.min(self:GetData("activepoint", 0) + iPerPoint, self:GetMaxPoints())
    local iAddPoint = iPoint - self:GetData("activepoint", 0)
    self:SetData("activepoint", iPoint)

    safe_call(self.RecordSysPoint, self, iAddPoint)
    return iAddPoint
end

function CSchedule:Add()
    self:AddDoneTimes()
    local iAddPoint = self:AddActivePoint()
    return iAddPoint
end

function CSchedule:IsDone()
    return self:GetActivePoint() >= self:GetMaxPoints()
end

function CSchedule:IsFullTimes()
    local iMaxTimes = self:GetMaxTimes()
    if iMaxTimes == -1 then
        return false
    end
    return self:GetDoneTimes() >= iMaxTimes
end

function CSchedule:PackData()
    return {
        scheduleid = self:GetData("id"),
        times = self:GetDoneTimes(),
        activepoint = self:GetActivePoint(),
        maxtimes = self:GetMaxTimes(),
    }
end

function CSchedule:RecordSysPoint(iAddPoint)
    local sType = self:GetScheduleInfo()["statistics"]
    local mData = res["daobiao"]["log"]["gamesys"][sType]
    if not mData then return end

    -- 这个100 只是用于统计sid
    local mReward = {[100] = iAddPoint}
    statistics.system_collect_reward(sType, mReward)
end

function CSchedule:NeedResetDaily()
    return self:Type() ~= gamedefines.SCHEDULE_TYPE.WEEKLY
end

function CSchedule:NeedResetWeekly()
    return self:Type() == gamedefines.SCHEDULE_TYPE.WEEKLY
end
