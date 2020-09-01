--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSkillFormula()
    local func = function (oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(oVictim, oAttack, oPerform, iDamage, iRatio)
    end
    oAction:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage, iRatio)
    if not oVictim or not oPerform then return end

    if oPerform:Type() < 5201 or oPerform:Type() > 5208 then return end
    if oPerform:PerformElement() ~= 2 then return end

    if math.random(100) > iRatio then return end

    oVictim:GS2CTriggerPassiveSkill(5125)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oVictim, iDamage)    
    oVictim:SetBoutArgs("immune_damage", 1)
end
