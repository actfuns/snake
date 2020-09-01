--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--玉清诀

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    oVictim.m_oBuffMgr:RemoveClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL)
end

function CPerform:NeedVictimTime()
    return false
end
