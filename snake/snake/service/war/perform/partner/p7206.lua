--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--炎盾

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    if oAttack.m_oBuffMgr:HasBuff(152) then return end

    oPerform:Effect_Condition_For_Attack(oAttack)
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function CPerform:GetAddAttackBuffRatio()
    local sExtArg = self:ExtArg()
    local mEnv = {level=self:Level()}
    local mExtArg = formula_string(sExtArg, mEnv)
    return mExtArg.ratio or 0
end
