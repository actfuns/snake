local global = require "global"

local statebase = import(service_path("state/statebase"))


function NewState(iState)
    local o = CState:New(iState)
    return o
end

CState = {}
CState.__index = CState
inherit(CState, statebase.CState)

-- 服务器等级加成(经验)
function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:ValidSave()
    return false
end

function CState:GetAddExpRatio()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return 0 end

    local iSGrade = oPlayer:GetServerGrade()
    local iPGrade = oPlayer:GetGrade()

    local iRatio = 0
    if iSGrade >= iPGrade then
        if iSGrade < self:GetMixSGrade() or 
            iPGrade < self:GetMinPGrade() then return 0 end

        iRatio = math.min(100, (iSGrade - iPGrade) * 2)
    else
        if (iPGrade - iSGrade) <= 2 then
            iRatio = (4/5 - 1) * 100   
        elseif (iPGrade - iSGrade) < 5 then
            iRatio = (2/3 - 1) * 100
        else
            iRatio = (1/3 - 1) * 100
        end
    end
    return iRatio
end

function CState:GetMinPGrade()
    return 35
end

function CState:GetMixSGrade()
    return 60
end

function CState:Hide()
    if self:GetAddExpRatio() <= 0 then
        return 1
    end
    return 0
end

function CState:GetOtherData()
    local iRatio = self:GetAddExpRatio()
    local mData  = {}
    table.insert(mData, {key="ratio",value=math.max(0, iRatio)})
    return mData
end
