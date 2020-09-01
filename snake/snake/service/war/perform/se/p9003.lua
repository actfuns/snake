--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--凝气术

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if oAttack:GetWid() ~= oVictim:GetWid() then return end

    if oVictim:IsDead() then return end

    local iAddMp = self:CalSkillFormula(oAttack, oVictim, 100)
    global.oActionMgr:DoAddMp(oVictim, iAddMp)
end

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_mp = oVictim:GetMaxMp()
    return mEnv
end

function CPerform:NeedVictimTime()
    return false
end

