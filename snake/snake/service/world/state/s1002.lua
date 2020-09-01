local global = require "global"
local res = require "base.res"
local record = require "public.record"

local statebase = import(service_path("state/statebase"))
local analy = import(lualib_path("public.dataanaly"))

CState = {}
CState.__index = CState
inherit(CState,statebase.CState)

function NewState(iState)
    local o = CState:New(iState)
    return o
end

function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:Load(mData)
    mData = mData or {}
    local iTime = mData["time"] or 0
    if iTime>0 then
        local iEndTime = iTime + get_time()
        self:SetData("time",iEndTime)
    end
end

function CState:Save()
    local mData = {}
    local iLeftTime = self:GetData("time")-get_time()
    if iLeftTime >0 then
        mData["time"] = iLeftTime
    end
    return mData
end

function CState:OnAddState(oPlayer)
    super(CState).OnAddState(self,oPlayer)
    local pid = self:GetInfo("pid")
    local iRewardTime = res["daobiao"]["huodong"]["dance"]["condition"][1]["reward_time"]
    self:AddTimeCb("RewardExp",iRewardTime * 1000,function ()
        _RewardExp(pid,self:ID())
    end)
    oPlayer:SyncSceneInfo({dance_tag=1})
end

function CState:OnRemoveState()
    local pid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:SyncSceneInfo({dance_tag=0})
    end
end

function CState:RewardExp(oPlayer)
    self:DelTimeCb("RewardExp")
    local pid = oPlayer:GetPid()
    local iRewardTime = res["daobiao"]["huodong"]["dance"]["condition"][1]["reward_time"]
    self:AddTimeCb("RewardExp",iRewardTime * 1000,function ()
        _RewardExp(pid,self:ID())
    end)
    local oHD = global.oHuodongMgr:GetHuodong("dance")
    if not oHD then return end
    oHD:Reward(pid,1001)
end

function CState:PackNetInfo()
    return {
        state_id = self.m_iID,
        time = self:GetData("time")-get_time(),
        name = self:Name(),
        desc = self:Desc(),
        data = self:GetOtherData(),
    }
end

function CState:GetOtherData()
    local mData = {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local mRes = res["daobiao"]["huodong"]["dance"]["condition"][1]
        local iCount = mRes["limitcnt"] - oPlayer.m_oTodayMorning:Query("dance",0)
        iCount = math.max(0,iCount)
        table.insert(mData,{key="count",value=iCount})
    end
    return mData
end

function _TimeOut(pid,iState)
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oState = oPlayer.m_oStateCtrl:GetState(iState)
    if not oState then return end
    oState:TimeOut(pid)
end

function _RewardExp(pid,iState)
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oState = oPlayer.m_oStateCtrl:GetState(iState)
    if not oState then return end
    oState:RewardExp(oPlayer)
end
