--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--隐忍

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", iPerform, func)
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or oAttack:IsDead() then
        return 0
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    if oAttack:GetHp() / oAttack:GetMaxHp() * 100 > mExtArg.hp_ratio then
        return -mExtArg.damaged_sub or 0
    else
        return mExtArg.damaged_add or 0
    end
end
