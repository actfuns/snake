--import module

local global = require "global"
local skynet = require "skynet"

local aibase = import(service_path("ai/aibase"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)

function CAI:ChoosePerform(oWar, oAction)
    local oPerformMgr = oAction.m_oPerformMgr
    local mPerform, iTotal = {}, 0
    for iPerform, oPerform in pairs(oPerformMgr:GetPerformTable()) do
        if not oPerform:IsActive() then
            goto continue
        end
        if not oPerform:AICheckValidPerform(oAction) then
            goto continue
        end
        local iTarget = oPerform:ChooseAITarget(oAction)
        if not iTarget then
            goto continue
        end

        iTotal = iTotal + 1
        local iPriority = oPerform:GetPerformPriority()
        mPerform[iPerform] = iPriority 
        ::continue::
    end
    if iTotal <= 0 then return end

    local iPerform = table_choose_key(mPerform)
    local oPerform = oAction:GetPerform(iPerform)
    if oPerform then
        local iTarget = oPerform:ChooseAITarget(oAction)
        return iPerform, iTarget
    end
end

function CAI:Command(oAction, bReturn)
    if not self:ValidCommand(oAction) then return end

    local lActionOrder, lActionRatio = self:GetActionOrder(oAction)
    for idx, iRatio in ipairs(lActionRatio) do
        if math.random(100) <= iRatio then
            local sCmd = lActionOrder[idx]
            local mRet = self:ExecuteCmd(oAction, sCmd, bReturn)
            return mRet
        end
    end
end

