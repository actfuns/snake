--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))
local pfload = import(service_path("perform/pfload"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TriggerFaBaoEffect(oVictim)
    if not oVictim or oVictim:IsDead() then return end

    local oBuff = oVictim.m_oBuffMgr:HasBuff(235)
    if not oBuff then return end

    local iRatio = self:CalSkillFormula(oVictim,nil,100,{})
    local func = function(oAttack, iValue, oPerform)
        return CheckResumeSP(iRatio, oAttack, iValue, oPerform)
    end
    oVictim.m_oBuffMgr:AddFunction("CheckResumeSP", 235, func)
end

function CheckResumeSP(iRatio, oAttack, iValue, oUsePerform)
    local iTrueValue = 0
    if pfload.GetPerformDir(oUsePerform:Type()) ~= "se" then
        return iTrueValue
    end
    return math.floor(iValue*iRatio/100)
end