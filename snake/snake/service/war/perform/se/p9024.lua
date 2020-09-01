--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--放下屠刀

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local oActionMgr = global.oActionMgr
    local bHit = oActionMgr:CalActionHit(oAttack, oVictim, self)
    if bHit then
        self:Effect_Condition_For_Victim(oVictim, oAttack)
    end
end

function CPerform:NeedVictimTime()
    return false
end
