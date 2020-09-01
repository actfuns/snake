--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--愤怒

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    oAction:Add("resumesp_add_ratio", mExtArg.ratio)
end

