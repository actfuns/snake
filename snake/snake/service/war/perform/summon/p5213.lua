--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))

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

function CPerform:DamageRatio(oAttack, oVictim)
    local iRatio = super(CPerform).DamageRatio(self, oAttack, oVictim)

    if oVictim:IsDefense() then
        iRatio = iRatio + self:CalSkillFormula(oAttack, oVictim, 100)
    end
    return iRatio
end

function CPerform:TruePerform(oAttack, oVictim, iDamage)
    oAttack:SetBoutArgs("ignore_defense", 1)
    super(CPerform).TruePerform(self, oAttack, oVictim, iDamage)
    oAttack:SetBoutArgs("ignore_defense", nil)
end
