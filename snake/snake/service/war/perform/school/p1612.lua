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
    local iUseWid = oAttack:Query("Record1612",0)
    if iUseWid == oVictim.m_iWid then
        return false
    end
    return true
end

--技能加速度
function CPerform:PerformTempAddSpeed(oAttack,iSpeed)
    return math.floor(self:Level() * 1.5)
end

function CPerform:TruePerform(oAttack,oVictim,iDamageRatio)
    if not oVictim or oVictim:IsDead() then
        return
    end
    self:Effect_Condition_For_Victim(oVictim,oAttack)
    oAttack:Set("Record1612",oVictim.m_iWid)
end