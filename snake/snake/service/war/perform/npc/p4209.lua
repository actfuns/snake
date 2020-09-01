local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--回春术

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:Set("keep_in_war", 1)

    local func = function(oWarrior)
        OnNewBout(oWarrior)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(oAttack)
    if oAttack:IsAlive() then return end

    oAttack:Add("die_bout", 1)
    if oAttack:Query("die_bout", 0) <= 2 then return end

    local iHp = math.floor(oAttack:GetMaxHp() * 0.5)
    oAttack:AddHp(iHp)
    oAttack:Set("die_bout", nil)
end
