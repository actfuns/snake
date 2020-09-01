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

function CAI:New(iAI)
    local o = super(CAI).New(self,iAI)
    return o
end

function CAI:Command(oAction)
    local oWar = oAction:GetWar()
    local mPerform = {}
    local mPerformAI = {}
    
    --选法术
    if oAction:IsNpc() then
        mPerformAI = oAction:GetData("perform_ai") or {}
    end
    local lPerformList = oAction:GetPerformList()
    for _, iPerform in ipairs(lPerformList) do
        local oPerform = oAction:GetPerform(iPerform)
        if not oPerform then
            goto continue
        end

        if not oPerform:IsActive() then
            goto continue
        end

        if not oPerform:AICheckValidPerform(oAction) then
            goto continue
        end
        mPerform[iPerform] = mPerformAI[iPerform] or 1
        ::continue::
    end
    if not next(mPerform) then
        oAction:AISetNormalAttack()
        return
    end
    local iPerform = table_choose_key(mPerform)
    if not iPerform then
        oAction:AISetNormalAttack()
        return
    end
    local oPerform = oAction:GetPerform(iPerform)
    
    --选目标
    local iTarget = oPerform:ChooseAITarget(oAction)
    if not iTarget then
        oAction:AISetNormalAttack()
        return
    end
    local mCmd = {
        cmd = "skill",
        data = {
            action_wlist = {oAction.m_iWid},
            select_wlist = {iTarget},
            skill_id = iPerform,
        }
    }
    oWar:AddBoutCmd(oAction.m_iWid,mCmd)
end
