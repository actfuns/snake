local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--魅惑

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local oBuff = oVictim.m_oBuffMgr:HasBuff(119)
    if oBuff then return end

    super(CPerform).TruePerform(self, oAttack, oVictim, iRatio)
end

function CPerform:NeedVictimTime()
    return false
end
