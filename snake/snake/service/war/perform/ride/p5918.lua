local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--自然力量

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnReceiveDamage(iPerform, oVictim, oAttack, oPerform, iDamage)
    end
    oPerformMgr:AddFunction("OnReceiveDamage", self.m_ID, func)
end

function OnReceiveDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform or iDamage <= 0 then return end

    if not oVictim:IsDefense() then return end

    if oVictim:IsDead() then return end

    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    mEnv.damage = iDamage
    local sExtArg = oPerform:ExtArg()
    local mExtArg = formula_string(sExtArg, mEnv)
    
    global.oActionMgr:DoAddMp(oVictim, mExtArg.add_mp)
end

