local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--灭灵

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        OnSeal(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnSeal", self.m_ID, func)
end

function OnSeal(iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim or oVictim:IsDead() then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform or not oUsePerform then return end
    
    if oUsePerform:Type() ~= 7602 then return end
    
    oPerform:Effect_Condition_For_Victim(oVictim, oAttack, mArgs)
end

