--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

CAI = {}
CAI.__index = CAI
inherit(CAI, logic_base_cls())

function CAI:New(id)
    local o = super(CAI).New(self)
    o.m_ID = id
    return o
end

function CAI:ValidCommand(oAction)
    if not oAction then return false end

    local oWar = oAction:GetWar()
    if not oWar then return false end

    return true
end

function CAI:GetActionOrder(oAction)
    local mConfig = self:GetActionConfig()
    local mDetail = mConfig[self.m_ID]
    if mDetail then
        return mDetail["action_order"], mDetail["action_ratio"]
    else
        return {"skill", "normal", "defense"}, {100, 100, 100}
    end
end

function CAI:GetPerformOrder(oAction)
    local mConfig = self:GetActionConfig()
    local mDetail = mConfig[self.m_ID]
    if mDetail then
        return mDetail["perform_order"], mDetail["perform_ratio"]
    else
        --oPerform:GetAIActionType()
        return {201, 101}, {100, 100}
    end
end

function CAI:GetAIPerformList(oAction)
    local mConfig = self:GetActionConfig()
    local mDetail = mConfig[self.m_ID]
    if mDetail["pflist"] and #mDetail["pflist"] > 0 then
        return mDetail["pflist"]
    end
end

function CAI:Command(oAction, bReturn)
    if not self:ValidCommand(oAction) then return end

    local lActionOrder, lActionRatio = self:GetActionOrder(oAction)
    for idx, iRatio in ipairs(lActionRatio) do
        if math.random(100) <= iRatio then
            local sCmd = lActionOrder[idx]
            local mRet = self:ExecuteCmd(oAction, sCmd, bReturn)
            if mRet then return mRet end
        end
    end
end

function CAI:ExecuteCmd(oAction, sCmd, bReturn)
    local oWar = oAction:GetWar()

    if sCmd == "skill" then
        return self:DoSkill(oWar, oAction, bReturn)
    elseif sCmd == "protect" then
        return self:DoProtect(oWar, oAction, bReturn)
    elseif sCmd == "normal" then
        return self:DoNormalAttack(oWar, oAction, bReturn)
    elseif sCmd == "summon" then
        return self:DoSummon(oWar, oAction, bReturn)
    else
        return self:DoDefense(oWar, oAction, bReturn)
    end
end

function CAI:DoSkill(oWar, oAction, bReturn)
    local iPerform, iTarget = nil, nil

    if self:GetAIPerformList() then
        iPerform, iTarget = self:SelectPerform(oWar, oAction)
    else
        iPerform, iTarget = self:ChoosePerform(oWar, oAction)
    end

    if not iPerform or not iTarget then return false end

    local mCmd = {
        cmd = "skill",
        data = {
            action_wlist = {oAction:GetWid()},
            select_wlist = {iTarget},
            skill_id = iPerform,
        },
    }
    if not bReturn then
        oWar:AddBoutCmd(oAction:GetWid(), mCmd)
        return true
    else
        return mCmd
    end
end

function CAI:SelectPerform(oWar, oAction)
    local oTargetMgr = global.oTargetMgr
    local lPerform = self:GetAIPerformList()
    local iTotal = #lPerform

    for idx = 1, iTotal do
        local iPerform = lPerform[idx].pfid
        local iAITarget = lPerform[idx].ai_target

        local oPerform = oAction:GetPerform(iPerform)
        if not oPerform then goto continue end

        if not oPerform:IsActive() then
            goto continue
        end

        oPerform:SetAITarget(iAITarget)

        local iTarget = oPerform:ChooseAITarget(oAction)
        if iTarget and oWar:GetWarrior(iTarget) then
            local oTarget = oWar:GetWarrior(iTarget)
            if global.oActionMgr:ValidPerform(oAction, oTarget, oPerform, false) then
                return iPerform, iTarget
            end
        end

        if idx >= iTotal then
            local lTarget = oPerform:TargetList(oAction)
            iTarget = oTargetMgr:ChooseAITarget(2, oAction, lTarget)
            if iTarget and oWar:GetWarrior(iTarget) then
                local oTarget = oWar:GetWarrior(iTarget)
                if global.oActionMgr:ValidPerform(oAction, oTarget, oPerform, false) then
                    return iPerform, iTarget
                end
            end
        end
        ::continue::
    end    
end

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
        local iActionType = oPerform:GetAIActionType()
        local iPriority = oPerform:GetPerformPriority()
        table_set_depth(mPerform, {iActionType}, iPerform, iPriority)
        ::continue::
    end
    if iTotal <= 0 then return end

    local lOrder, lRatio = self:GetPerformOrder(oAction)
    for idx, iClass in ipairs(lOrder) do
        if math.random(100) > lRatio[idx] then
            goto continue
        end

        local mInfo = mPerform[iClass] or {}
        local iPerform = table_choose_key(mInfo)
        if not iPerform then goto continue end

        local oPerform = oAction:GetPerform(iPerform)
        if not oPerform then goto continue end

        local iTarget = oPerform:ChooseAITarget(oAction)
        if not iTarget then goto continue end

        do return iPerform, iTarget end

        ::continue::
    end
end

function CAI:DoProtect(oWar, oAction, bReturn)
    local oTargetMgr = global.oTargetMgr
    local lFriend = oAction:GetFriendList(false)
    lFriend = extend.Table.filter(lFriend, function(oWarrior)
        return oWarrior:GetWid() ~= oAction:GetWid()
    end)
    local iTarget = oTargetMgr:ChooseAITarget(2, oAction, lFriend)
    if not iTarget then return false end

    local mCmd = {
        cmd = "protect",
        data = {
            action_wid = oAction:GetWid(),
            select_wid = iTarget,
        },
    }
    if not bReturn then
        oWar:AddBoutCmd(oAction:GetWid(), mCmd)
        return true
    else
        return mCmd
    end
end

function CAI:GetNormalAttackTarget(oAction)
    local oTargetMgr = global.oTargetMgr
    local lTarget = oAction:GetEnemyList(false)
    return oTargetMgr:ChooseAITarget(2, oAction, lTarget)
end

function CAI:DoNormalAttack(oWar, oAction, bReturn)
    if oAction:HasKey("attack_disable") then return false end

    local iTarget = self:GetNormalAttackTarget(oAction)
    if not iTarget then return false end

    local mCmd = {
        cmd = "normal_attack",
        data = {
            action_wid = oAction:GetWid(),
            select_wid = iTarget,
        },
    }
    if not bReturn then
        oWar:AddBoutCmd(oAction:GetWid(), mCmd)
        return true
    else
        return mCmd
    end
end

function CAI:ValidDoSummon(oWar, oAction)
    local iSummon = oAction:Query("curr_sum")
    if not iSummon then return false end
    
    local oSummon = oWar:GetWarrior(iSummon)
    if oSummon and oSummon:IsAlive() then return false end

    return true
end

function CAI:DoSummon(oWar, oAction, bReturn)
    local iWarType = oWar:GetWarType()
    if iWarType == gamedefines.WAR_TYPE.PVP_TYPE or oWar:IsBossWar() then
        if self:ValidDoSummon(oWar, oAction) and math.random(100) <= 80 then
            return self:TrueDoSummon(oWar, oAction, bReturn)
        end
    end
    if oAction:HasKey("attack_disable") and oAction:HasKey("mag_disable") and oAction:HasKey("phy_disable") then
        if self:ValidDoSummon(oWar, oAction) then
            return self:TrueDoSummon(oWar, oAction, bReturn)
        end
    end
    return false
end

function CAI:TrueDoSummon(oWar, oAction, bReturn)
    local mSummon = oAction:GetData("summon")
    if not mSummon then return false end
    local mKeep = mSummon.sumkeep or {}
    if table_count(mKeep) <= 0 then return false end

    local mJoined = oAction:Query("summon", {})

    local iFightCnt = global.oActionMgr:GetFightSummonCnt(oAction)
    if table_count(mJoined) >= iFightCnt then return false end

    for iSummon, mSummon in pairs(mKeep) do
        if not mJoined[mSummon.sum_id] then
            local mCmd = {
                cmd = "summon",
                data = {
                    action_wid = oAction:GetWid(),
                    sumdata = {
                        sumdata = mSummon,
                    },
                },
            }
            if not bReturn then
                oWar:AddBoutCmd(oAction:GetWid(), mCmd)
                return true
            else
                return mCmd
            end
        end
    end
    return false
end

function CAI:DoDefense(oWar, oAction, bReturn)
    local mCmd = {
        cmd = "defense",
        data = {
            action_wid = oAction:GetWid(),
        },
    }
    if not bReturn then
        oWar:AddBoutCmd(oAction:GetWid(), mCmd)
        return true
    else
        return mCmd
    end
end

function CAI:GetActionConfig()
    return res["daobiao"]["ai"]["action"]
end
