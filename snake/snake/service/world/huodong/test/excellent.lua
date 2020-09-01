-- import module
local global  = require "global"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local activitybase = import(service_path("huodong.huodongbase"))

CExcellent = {}
CExcellent.__index = CExcellent
inherit(CExcellent, activitybase.CHuodong)

function NewHuodong(sHuodongName)
    return CExcellent:New(sHuodongName)
end

function CExcellent:New(sHuodongName)
    local o = super(CExcellent).New(self, sHuodongName)
    return o
end

function CExcellent:Init()
    self.m_iScheduleID = 1008
    local oHuodongMgr = global.oHuodongMgr
    -- oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_READY, "全天开启")
end

function CExcellent:GetStartTime()
    return "10:00"
end

function CExcellent:NewHour(mNow)
    -- local iHour = mNow.date.hour
    -- if iHour == 0 then 
         -- local oHuodongMgr = global.oHuodongMgr
         -- oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_READY, "全天开启")
    -- end
end
