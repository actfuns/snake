local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--群伤抵抗

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(iPerform, oVictim, oAttack, oPerform, iDamage)
    end
    oPerformMgr:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function OnImmuneDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    if not oUsePerform or not oUsePerform:IsGroupPerform() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oVictim, oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    oVictim:AddBoutArgs("immune_damage_ratio", mExtArg.ratio)
end

