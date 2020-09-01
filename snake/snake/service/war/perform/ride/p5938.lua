local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--怒火中烧

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iCritRatio)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform, iCritRatio)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform, iCritRatio)
    if oAttack:QueryBoutArgs("IsPhyCrit", 0) == 1 then
        local oPerform = oAttack:GetPerform(iPerform)
        if not oPerform then return 0 end

        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oAction)
        local mExtArg = formula_string(sExtArg, mEnv)

        return mExtArg.add_ratio or 10
    end
    return 0
end

