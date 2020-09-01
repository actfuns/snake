--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:MaxRange()
    local iCnt = 2
    if self:Level() >= 40 then
        iCnt = 3
    elseif self:Level() >= 80 then
        iCnt = 4
    end
    return iCnt
end

function CPerform:ConstantDamage(oAttack,oVictim,iRatio)
    local iDamage = self:CalSkillFormula(oAttack,oVictim,iRatio)
    if oVictim:IsNpc() then
        iDamage = iDamage * 3
    end
    return iDamage
end