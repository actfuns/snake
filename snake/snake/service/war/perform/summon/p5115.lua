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
    local func = function (oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio)
    end
    oPerformMgr:AddFunction("OnAttacked",self.m_ID, func)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio)
    if not oVictim or oVictim:IsDead() or oAttack:HasKey("sneak") then return end
    if not oAttack:IsVisible(oVictim) then return end
    
    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end

    if oPerform and oPerform:IsGroupPerform() and oPerform:DoGroupRatio() then return end

    if oPerform and oPerform:GetData("PerformAttackCnt",0) > 1 then return end

    if mArgs and mArgs.bNotBack then return end

    if math.random(100) > iRatio then return end

    local iRealDamage = math.floor(iDamage * 0.5)
    if iRealDamage <= 0 then return end

    oVictim:GS2CTriggerPassiveSkill(5115)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoSubHp(oAttack, iRealDamage, oVictim)
end
