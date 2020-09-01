local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--清心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack,oVictim,iDamageRatio)
    oVictim.m_oBuffMgr:RemoveClassBuffInclude(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, {["封印"]=1})
end

function CPerform:NeedVictimTime()
    return false
end
