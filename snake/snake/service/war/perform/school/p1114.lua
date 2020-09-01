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
    if oAttack:GetHp() >= oAttack:GetMaxHp() // 10 then
        return true
    end
    return false
end

--技能加速度
function CPerform:PerformTempAddSpeed(oAttack,iSpeed)
    local iSpeed = math.floor(self:Level() /2 + 50)
    oAttack:AddBoutArgs("speed_ratio",50)
    return iSpeed
end

function CPerform:TruePerform(oAttack,oVictim,iDamageRattio)
    oAttack:Add("damage_addratio",-40)
    super(CPerform).TruePerform(self,oAttack,oVictim,iDamageRattio)
    oAttack:Add("damage_addratio",40)
end