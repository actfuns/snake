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

function CPerform:SelfValidCast(oAttack,oVictim)
    if oAttack:GetHp() < oAttack:GetMaxHp() // 10 then
        return false
    end
    if oAttack:GetHp() > oAttack:GetMaxHp() // 2 then
        return false
    end
    return true
end

function CPerform:TruePerform(oAttack,oVictim,iDamage)
    oAttack:Add("damage_addratio",50)
    super(CPerform).TruePerform(self,oAttack,oVictim,iDamage)
    oAttack:Add("damage_addratio",-50)
end