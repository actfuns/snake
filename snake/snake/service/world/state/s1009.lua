local global = require "global"
local statebase = import(service_path("state/statebase"))


function NewState(iState)
    local o = CState:New(iState)
    return o
end

CState = {}
CState.__index = CState
inherit(CState, statebase.CState)


function CState:ReConfig(iPid, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iAddTime = mData.time or 0
    if iAddTime <= 0 then return end

    local iTime = self:GetData("time", get_time())
    iTime = math.min(iTime+iAddTime, get_time()+24*3600)
    self:SetData("time", iTime)
    self:Refresh(iPid)

    local func = function()
        self:TimeOut(iPid)
    end
    self:DelTimeCb("timeout")
    self:AddTimeCb("timeout", (iTime-get_time())*1000, func)
end

function CState:GetExpRatioByName(sName)
    local sFormula = self:GetConfigData()["state_formula"]
    if not sFormula or #sFormula <= 0 then return 0 end

    local mRatio = formula_string(sFormula, {})
    return mRatio[sName] or 0
end
