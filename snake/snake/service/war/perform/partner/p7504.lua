local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--白蛇魅影

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func1 = function(oAttack, oVictim, oPerform)
        return MaxRange(oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("MaxRange", self.m_ID, func1)

    local func2 = function(oAttack, oVictim, oUsePerform)
        return OnSealRatio(oAttack, oVictim, oUsePerform)
    end
    oPerformMgr:AddFunction("OnSealRatio", self.m_ID, func2)
end

function MaxRange(oAttack, oVictim, oUsePerform)
    if oUsePerform:Type() ~= 7503 then return 0 end

    local oPerform = oAttack:GetPerform(7504)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    return mExtArg.range or 0
end

function OnSealRatio(oAttack, oVictim, oUsePerform)
    if oUsePerform:Type() ~= 7503 then return 0 end

    if oUsePerform:GetData("PerformAttackCnt", 0) ~= 1 then
        return 0
    end

    local oPerform = oAttack:GetPerform(7504)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    return mExtArg.ratio or 0
end
