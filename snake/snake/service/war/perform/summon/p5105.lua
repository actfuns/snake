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
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack2(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    end
    oPerformMgr:AddFunction("OnAttack2",self.m_ID, func)
end

function OnAttack2(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    if iDamage <= 0 then return end

    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end

    if oPerform and oPerform:IsGroupPerform() then return end

    if oVictim and oVictim:HasKey("disable_suck_blood") then
        return
    end
    
    local iHP = math.floor(iRatio * iDamage / 100)
    if iHP <= 0 then return end
    
    oAttack:GS2CTriggerPassiveSkill(5105)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oAttack, iHP)
end
