-- import module
local global  = require "global"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

CNormal = {}
CNormal.__index = CNormal
inherit(CNormal, huodongbase.CHuodong)

function NewHuodong(sHuodongName)
    return CNormal:New(sHuodongName)
end

function CNormal:New(sHuodongName)
    local o = super(CNormal).New(self, sHuodongName)
    return o
end

function CNormal:Init()
    self.m_iScheduleID = 1007
    local oHuodongMgr = global.oHuodongMgr
    -- oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_READY, "全天开启")
end

function CNormal:GetStartTime()
    return "10:00"
end

function CNormal:NewHour(mNow)
    -- local iHour = mNow.date.hour
    -- if iHour == 0 then
        -- local oHuodongMgr = global.oHuodongMgr
        -- oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_READY, "全天开启")
    -- end
end
