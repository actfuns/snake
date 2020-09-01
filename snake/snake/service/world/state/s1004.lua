local global = require "global"
local res = require "base.res"

local statebase = import(service_path("state/statebase"))

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

function CState:Click(oPlayer,mData)
    oPlayer.m_oBaseCtrl:RewardDoublePoint()
    self:Refresh(oPlayer:GetPid())
end

function CState:GetOtherData()
    local oWorldMgr = global.oWorldMgr
    local pid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mPoint = oPlayer.m_oBaseCtrl:GetData("double_point",0)
    local iPoint = 0
    if mPoint ~= 0 then
        iPoint = mPoint.point or 0
    end
    local mData = {}
    table.insert(mData,{key="point",value=iPoint})
    return mData
end
