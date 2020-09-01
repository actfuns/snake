local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--复生

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:SelfValidCast(oAttack, oVictim)
    if not oVictim:IsDead() then return false end
    return true
end

function CPerform:TargetList(oAttack)
    local lTarget = super(CPerform).TargetList(self, oAttack)
    local lResult = {}
    for _, oTarget in pairs(lTarget) do
        if not oTarget:HasKey("revive_disable") then
            table.insert(lResult, oTarget)
        end
    end
    return lResult
end


