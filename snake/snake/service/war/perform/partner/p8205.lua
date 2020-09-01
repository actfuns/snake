--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--嗜杀

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamage(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamage", self.m_ID, func)
end

function OnCalDamage(iPerform, oAttack, oVictim, oPerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oAttack or not oVictim then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    mEnv.attack_speed = oAttack:QueryAttr("speed")
    mEnv.victim_speed = oVictim:QueryAttr("speed")
    local mExtArg = formula_string(sExtArg, mEnv)
    return mExtArg.damage_add or 0
end

