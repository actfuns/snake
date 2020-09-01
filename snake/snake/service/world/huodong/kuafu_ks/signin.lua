local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local huodongbase = import(service_path("huodong.huodongbase"))
local analylog = import(lualib_path("public.analylog"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日签到"
inherit(CHuodong,huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_sName = sHuodongName
    return o
end


function CHuodong:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:AddTrigger(oPlayer)
    end
end

function CHuodong:AddTrigger(oPlayer)
    if not oPlayer then return end
    local func = function(sEvent, mData)
        self:CollectActivePoint(mData)
    end
    oPlayer.m_oScheduleCtrl:AddEvent(self, "addactive", func)
end

function CHuodong:CollectActivePoint(mData)
    local iPid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mInfo = oPlayer.m_oTodayMorning:Query("ks_schedule", {})

    local iAdd = mData.addpoint
    local iTotal = mData.totalpoint
    mInfo.addpoint = (mInfo.addpoint or 0) + iAdd
    mInfo.total = iTotal
    oPlayer.m_oTodayMorning:Set("ks_schedule", mInfo)
end

