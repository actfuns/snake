--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:GetTriggerValue(oAttack)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iSelfRatio = mExtArg.ratio_self or 0
    local iRatio = mExtArg.ratio or 0
    if math.random(1,100)<iRatio then
        return iSelfRatio
    end
    return 1
end
