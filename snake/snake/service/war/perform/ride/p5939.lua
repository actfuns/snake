local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--重创追击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oSummon)
        OnAddSummon(iPerform, oAction, oSummon)
    end
    oPerformMgr:AddFunction("OnAddSummon", self.m_ID, func)
end

function OnAddSummon(iPerform, oAction, oSummon)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttackDelay(oAction, iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oSummon:Set("p5939", 1)
    oSummon.m_oPerformMgr:AddFunction("OnAttackDelay", iPerform, func)
end

function OnAttackDelay(oAction, iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    if not oAttack:IsSummonLike() or oAttack:IsDead() then return end

    if oUsePerform and oUsePerform:IsGroupPerform() then return end
    if oUsePerform and oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end

    if not mArgs or not mArgs.is_critical or mArgs.is_critical ~= 1 then
        return
    end

    local lTarget = {}
    for _, oWarrior in ipairs(oAttack:GetEnemyList() or {}) do
        if oWarrior:GetWid() ~= oVictim:GetWid() then
            table.insert(lTarget, oWarrior)
        end
    end
    oAttack:AddBoutArgs("iComboCnt", 1)
    if next(lTarget) and mArgs and mArgs.is_critical then
        local oTarget = lTarget[math.random(#lTarget)]
        global.oActionMgr:WarNormalAttack(oAttack, oTarget, {perform_time=700})
    end
end
