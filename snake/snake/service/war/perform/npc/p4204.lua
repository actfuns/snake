local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--复仇1

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:AddCallBackFunc(oWarrior)
    local func1 = function(oAttack, oVictim, oPerform)
        return MaxRange(oAttack, oVictim, oPerform)
    end
    oWarrior:AddFunction("MaxRange", self.m_ID, func1)

    local func2 = function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(oAttack, oVictim, oPerform)
    end
    oWarrior:AddFunction("OnCalDamageResultRatio", self.m_ID, func2)
end

function MaxRange(oAttack, oVictim, oPerform)
    if oPerform and oPerform:ActionType() == gamedefines.WAR_ACTION_TYPE.SEAL then
        return 1
    end
    return 0
end

function OnCalDamageResultRatio(oAttack, oVictim, oPerform)
    return 100
end
