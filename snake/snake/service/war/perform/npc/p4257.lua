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

-- 心魔蚀心
function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iPerform)
    end
    oPerformMgr:AddFunction("OnAttack",self.m_ID, func)
end

function OnAttack(oAttack, oVictim, oUsePerform, iDamage, mArgs, iPerform)
    if not oVictim or oVictim:IsDead() then return end

    -- oVictim:GS2CTriggerPassiveSkill(4257)
    local oPerform = oAttack:GetPerform(iPerform)
    oPerform:Effect_Condition_For_Victim(oVictim, oAttack)
end
