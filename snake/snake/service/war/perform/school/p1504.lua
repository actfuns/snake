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

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    local iMp = self:CalSkillFormula(oAttack,oVictim,iRatio)
    if math.random(100) <= oAttack:Query("mp_critical_ratio", 0) then
        iMp = math.floor(iMp * 2)
    end
    global.oActionMgr:DoAddMp(oAttack, iMp)
end

function CPerform:NeedVictimTime()
    return false
end
