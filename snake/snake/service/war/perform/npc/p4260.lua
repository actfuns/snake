--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--箭芒
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iPerform)
    end
    oPerformMgr:AddFunction("OnAttack",self.m_ID, func)
end

function OnAttack(oAttack, oVictim, oUsePerform, iDamage, mArgs, iPerform)
    if not oVictim or oVictim:IsDead() then return end
    if oVictim.m_oBuffMgr:HasBuff(208) then
        return
    end
    --print("AddBuff",208)
    oVictim.m_oBuffMgr:AddBuff(208,3,{})
end
