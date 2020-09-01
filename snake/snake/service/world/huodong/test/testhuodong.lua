--import module
local global  = require "global"
local extend = require "base.extend"

local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1001
    return o
end

function CHuodong:GetStartTime()
    return "10:00"
end

function CHuodong:NewHour(mNow)
    local iWeekDay = mNow.date.wday
    local iHour = mNow.date.hour
    if iWeekDay == 2 and iHour == 21 then
        local oHuodongMgr = global.oHuodongMgr
        oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, 2, "10:00")
    end
end