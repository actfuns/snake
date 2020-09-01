--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--我见忧怜

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


function CPerform:CalWarrior(oAction, oPerformMgr)
    local func1 = function(oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(iPerform, oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttacked", self.m_ID, func1)
end

function OnAttacked(iPerform, oVictim, oAttack, oPerform, iDamage, mArgs)
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oVictim, oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    if oVictim:QueryBoutArgs("set_immune", 0) == 0 then
        oVictim:SetBoutArgs("set_immune", 1)
        oVictim:AddBoutArgs("immune_damage_ratio", mExtArg.immune_damage_ratio)
    else
        oVictim:SetBoutArgs("set_immune", 0)
        oVictim:AddBoutArgs("immune_damage_ratio", -mExtArg.immune_damage_ratio)
    end
end
