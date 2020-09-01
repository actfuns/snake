--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--野兽之力

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    self:Effect_Condition_For_Victim(oVictim, oAttack)
end

function CPerform:NeedVictimTime()
    return false
end
