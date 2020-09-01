--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--连环咒

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oPerform, lVictim)
        OnEndPerform(iPerform, oAttack, oPerform, lVictim)
    end
    oPerformMgr:AddFunction("OnEndPerform", self.m_ID, func)
end

function OnEndPerform(iPerform, oAttack, oUsePerform, lVictim)
    if oAttack:IsDead() then return end

    if oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then
        return
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    local sKey = string.format("ignore_perform_again_%s", oUsePerform:Type())
    if oAttack:QueryBoutArgs(sKey) then
        return
    end

    if oAttack:QueryBoutArgs("iChaseCnt", 0) >= 1 then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio then
        local lEnemy = oAttack:GetEnemyList()
        if not next(lEnemy) then return end

        local lVictim1 = {}
        if not lVictim[1] or lVictim[1]:IsDead() then
            local mTarget = oUsePerform:PerformTarget(oAttack, lEnemy[1])
            for _, iWid in ipairs(mTarget) do
                table.insert(lVictim1, oWar:GetWarrior(iWid))
            end
        else
            lVictim1 = lVictim
        end
        oAttack:SetBoutArgs(sKey, oPerform:Type())
        oAttack:AddBoutArgs("iChaseCnt", 1)
        oAttack:Add("damage_addratio", -mExtArg.damage_ratio)
        oUsePerform:Perform(oAttack, lVictim1)
        oAttack:Add("damage_addratio", mExtArg.damage_ratio)
    end
end

