local global = require "global"

local statebase = import(service_path("state/statebase"))


function NewState(iState)
    local o = CState:New(iState)
    return o
end

CState = {}
CState.__index = CState
inherit(CState, statebase.CState)

-- 获得BUFF“喜气洋洋”（有效时间60分钟内，获得的人物经验增加10%，该效果不可叠加）   
function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:GetAddExpRatio()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return 0 end

    local sFormula = self:GetConfigData()["state_formula"]
    if not sFormula or #sFormula <= 0 then return 0 end

    local mRatio = formula_string(sFormula, {})
    return mRatio.exp_ratio
end

function CState:GetOtherData()
    local iRatio = self:GetAddExpRatio()
    local mData  = {}
    table.insert(mData, {key="ratio",value=math.max(0, iRatio)})
    return mData
end
