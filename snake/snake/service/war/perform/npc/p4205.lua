local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--复仇2

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:AddCallBackFunc(oWarrior)
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(oAttack, oVictim, oPerform)
    end
    oWarrior:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(oAttack, oVictim, oPerform)
    return 100
end
