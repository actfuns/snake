local global = require "global"

local statebase = import(service_path("state/statebase"))


function NewState(iState)
    local o = CState:New(iState)
    return o
end

CState = {}
CState.__index = CState
inherit(CState, statebase.CState)

-- 组队队长加成(经验)
function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:ValidSave()
    return false
end

function CState:GetLeaderExpRaito(sName, iMemCnt)
    local sFormula = self:GetConfigData()["state_formula"]
    if not sFormula or #sFormula <= 0 then return 0 end

    local mRatio = formula_string(sFormula, {count=iMemCnt})
    return mRatio[sName] or 0
end
