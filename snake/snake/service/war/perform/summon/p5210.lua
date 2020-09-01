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

function CPerform:CalDamageRatio(oAttack, oVictim)
    local iMaxHp = oAttack:GetMaxHp()
    local iHp = oAttack:GetHp()
    
    local iExtRatio = ((iMaxHp - iHp) / iMaxHp) / (8 - self:Level() * 0.6) * 100 + 10 + self:Level() * 2 
    if iExtRatio > 0 then
        return iExtRatio
    end
    return 0
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRattio)
    local iRatio = self:CalDamageRatio(oAttack, oVictim)
    oAttack:Add("damage_addratio", iRatio)
    super(CPerform).TruePerform(self, oAttack, oVictim, iDamageRattio)
    oAttack:Add("damage_addratio", -iRatio)
end