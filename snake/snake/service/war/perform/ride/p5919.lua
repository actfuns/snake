local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--逆转阴阳

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    self.m_iBout = -99
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(iPerform, oVictim, oAttack, oPerform, iDamage)
    end
    oPerformMgr:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function OnImmuneDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    local oWar = oVictim:GetWar()
    if not oWar or iDamage<=0 then return end

    if oVictim:IsDead() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform or not oUsePerform then return end
    
    if oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then
        return
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    mEnv.damage = iDamage
    local mExtArg = formula_string(sExtArg, mEnv)
    if oVictim:GetHp() > oVictim:GetMaxHp()*mExtArg.hp_ratio//100 then
        return
    end

    if mExtArg.hp_add <= 0 then return end

    if oWar:CurBout() - oPerform.m_iBout <= mExtArg.bout_freq then
        return
    end

    oPerform.m_iBout = oWar:CurBout()
    oVictim:SetBoutArgs("immune_damage", 1)
    global.oActionMgr:DoAddHp(oVictim, mExtArg.hp_add)
end

