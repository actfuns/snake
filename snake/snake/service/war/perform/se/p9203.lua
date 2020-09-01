--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--连击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oVictim or oVictim:IsDead() then return end

    if oUsePerform or iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    mArgs.perform_time = 700
    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    if math.random(100) <= mExtArg.ratio then
        oAttack:AddBoutArgs("damage_ratio", mExtArg.damage_ratio)
        global.oActionMgr:WarNormalAttack(oAttack, oVictim, mArgs)
        oAttack:AddBoutArgs("damage_ratio", -mExtArg.damage_ratio)
    end
end
