local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--装死

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(iPerform, oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttacked", self.m_ID, func)
end

function OnAttacked(iPerform, oVictim, oAttack, oUsePerform, iDamage, mArgs)
    if not mArgs or not mArgs.is_critical then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    oPerform:Effect_Condition_For_Attack(oVictim)
end
