local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--副作用

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAction, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    oAction:Add("usedrug_add_ratio", mExtArg.usedrug_add_ratio)
    oAction:Add("res_drug_add_ratio", mExtArg.res_drug_add_ratio)
end


