--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--笑里藏刀

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if oVictim and oVictim:IsPlayerLike() and oVictim:IsAlive() then
        local iSub = self:CalSkillFormula(oAttack, oVictim, iRatio)
        oVictim:AddSP(-iSub)
    end
end

function CPerform:NeedVictimTime()
    return false
end
