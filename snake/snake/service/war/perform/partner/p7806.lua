--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--普度众生

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    local iAddMaxHp = oAction:GetMaxHp() * mExtArg.max_hp // 100
    local iMaxHp = oAction:GetMaxHp()
    oAction:SetData("max_hp", iMaxHp+iAddMaxHp)
    oAction:SetData("hp", oAction:GetMaxHp())
    oAction:StatusChange("hp", "max_hp")
end

