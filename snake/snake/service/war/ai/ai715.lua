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

-- AI: 命中轮回时如果有死亡目标，则随机复活一个，没有则重新抽取技能
-- 因为npc技能直接由概率选中，轮回没过滤作用目标状态，所以选中时有可能没有死亡目标

function CAI:Command(oAction)
    local mPerform = self:GetAvailablePerform(oAction)
    local iPerform, iTarget = self:ChooseOnePerform(oAction, mPerform)
    if iPerform == 1205 and not iTarget then --命中了轮回但没目标
        mPerform[iPerform] = nil --去除轮回权重，重新抽取技能
        iPerform, iTarget = self:ChooseOnePerform(oAction, mPerform)
    end
    if not iPerform or not iTarget then
        oAction:AISetNormalAttack()
        return
    end
    self:AIAddBoutCmd(oAction, iPerform, iTarget)
end

function CAI:GetAvailablePerform(oAction)
    local mPerform = {}
    local mPerformAI = {}

    if oAction:IsNpc() then
        mPerformAI = oAction:GetData("perform_ai") or {}
    end
    local lPerformList = oAction:GetPerformList()
    for _, iPerform in ipairs(lPerformList) do
        local oPerform = oAction:GetPerform(iPerform)
        if oPerform and oPerform:IsActive() and oPerform:AICheckValidPerform(oAction) then
            mPerform[iPerform] = mPerformAI[iPerform] or 1
        end
    end
    return mPerform
end

function CAI:ChooseOnePerform(oAction, mPerform)
    local iPerform = table_choose_key(mPerform)
    local oPerform = oAction:GetPerform(iPerform)
    if oPerform then
        local iTarget = oPerform:ChooseAITarget(oAction)
        return iPerform, iTarget
    end
end

function CAI:AIAddBoutCmd(oAction, iPerform, iTarget)
    local oWar = oAction:GetWar()
    local iWid = oAction.m_iWid
    local mCmd = {
        cmd = "skill",
        data = {
            action_wlist = {iWid},
            select_wlist = {iTarget},
            skill_id = iPerform,
        }
    }
    oWar:AddBoutCmd(iWid, mCmd)
end