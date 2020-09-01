local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodong = import(service_path("huodong.kuafu_gs.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "KS_蜀山论道"
inherit(CHuodong, huodong.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    self.m_iScheduleID = 1039
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iPrepareTime = 0
    self.m_sKuaFu = nil
    return o
end

function CHuodong:InitHuoDong(mInfo)
    self.m_iPrepareTime = mInfo.pre_time or 0
    self.m_iStartTime = mInfo.start_time or 0
    self.m_iEndTime = mInfo.end_time or 0
end

function CHuodong:OnStartKSHuodong(sKuaFu, mInfo)
    self.m_sKuaFu = sKuaFu
    self:InitHuoDong(mInfo)

    local sTime = get_time_format_str(self.m_iStartTime, "%H:%M")
    -- TODO
    global.oHuodongMgr:SetHuodongState("singlewar", self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_START, sTime)
end

function CHuodong:OnEndKSHuodong(sKuaFu)
    local sTime = get_time_format_str(self.m_iStartTime, "%H:%M")
    -- TODO 
    self:InitHuoDong({})
    self.m_sKuaFu = nil
    global.oHuodongMgr:SetHuodongState("singlewar", self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_END, sTime)
end

function CHuodong:ValidShow(oPlayer)
    local iCurrTime = get_time()
    return iCurrTime >= self.m_iPrepareTime and iCurrTime < self.m_iEndTime
end

function CHuodong:GetNPCMenu()
    return "参加跨服论道"
end

function CHuodong:PackEnterInfo()
    return {
        hdname = "singlewar"
    }
end

function CHuodong:JoinGame(oPlayer, oNpc)
    if not self.m_sKuaFu then return end

    if not self:ValidShow(oPlayer) then return end

    global.oKuaFuMgr:TryEnterKS(oPlayer, self.m_sKuaFu, self:PackEnterInfo())
end