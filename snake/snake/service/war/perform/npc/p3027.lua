local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--走火入魔
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iPerform)
    end
    oPerformMgr:AddFunction("OnAttack",self.m_ID, func)
end

function OnAttack(oAttack, oVictim, oUsePerform, iDamage, mArgs, iPerform)
    if not oVictim or oVictim:IsDead() then return end
    oVictim.m_oBuffMgr:AddBuff(244, 3, {})
end
