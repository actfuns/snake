local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if not oAttack or oAttack:IsDead() then return end

    local iPos = self:SelectSummonPos(oAttack)
    if not iPos then return end

    local iAddRatio = 0
    if oAttack and oAttack:GetPerform(9505) then
        local oPerform = oAttack:GetPerform(9505)
        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oAttack)
        local mExtArg = formula_string(sExtArg, mEnv)
        iAddRatio = iAddRatio + (mExtArg.attr_add_ratio or 0)
    end

    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    local mInfo = {}
    for sKey, rVal in pairs(mExtArg) do
        if sKey ~= "model" then
            if sKey ~= "grade" then
                mInfo[sKey] = math.floor(oAttack:GetData(sKey, 0) * rVal / 100 * (100 + iAddRatio) / 100)
            else
                mInfo[sKey] = math.floor(oAttack:GetData(sKey, 0) * rVal / 100)
            end
        else
            for iLevel = 1, self:Level() do
                local mData = rVal[iLevel]
                if mData then
                    mInfo.type = mData.type
                    mInfo.name = mData.name
                    mInfo.model_info = table_copy(mData.model_info)
                    mInfo.perform = {}
                    mInfo.perform_ai = {}
                    for _, iPerform in pairs(mData.skill) do
                        mInfo.perform[iPerform] = self:Level()
                        mInfo.perform_ai[iPerform] = 100
                    end
                end
            end
        end
    end

    if not next(mInfo) then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    mInfo.hp = mInfo.max_hp
    mInfo.mp = mInfo.max_mp
    mInfo.aitype = 101
    mInfo.expertskill = oAttack:GetData("expertskill", {})
    local oWarrior = oWar:AddNpcWarrior(oAttack:GetCampId(), mInfo, iPos, nil, true)
    oWarrior.m_bFlagWarrior = 1405
    oWarrior:Set("ignore_count", 1)
end

function CPerform:IsDisabled(oAttack)
    local bRet = super(CPerform).IsDisabled(self, oAttack)
    if bRet then return true end

    for _,w in pairs(oAttack:GetFriendList(true)) do
        if w.m_bFlagWarrior and w.m_bFlagWarrior == 1405 then
            if oAttack:IsPlayer() then
                oAttack:Notify("本方同时只能存在一只天兵")
            end
            return true
        end
    end
    local iPos = self:SelectSummonPos(oAttack)
    if not iPos and oAttack:IsPlayer() then
        oAttack:Notify("已达最大作战人数")
        return true
    end

    return false
end

function CPerform:SelectSummonPos(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local iCamp = oAction:GetCampId()
    local lPosList = {11, 12, 13, 14}
    for _, iPos in ipairs(lPosList) do
        if not oWar:GetWarriorByPos(iCamp, iPos) then
            return iPos
        end
    end
end

function CPerform:NeedVictimTime()
    return false
end
