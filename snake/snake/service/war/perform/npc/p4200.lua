--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--定心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oAttack, oVictim, oPerform, iSealRatio)
        return OnSealedRatio(oAttack, oVictim, oPerform, iSealRatio)
    end
    oPerformMgr:AddFunction("OnSealedRatio", self.m_ID, func)
end

function OnSealedRatio(oAttack, oVictim, oPerform, iSealRatio)
    return -10000
end
