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
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamagedResultRatio(oAttack, oVictim, oPerform, iRatio)
    end
    oAction:AddFunction("OnCalDamagedResultRatio", self.m_ID, func)
end

function OnCalDamagedResultRatio(oAttack, oVictim, oPerform, iRatio)
    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return 0 end

    if math.random(100) > iRatio then return 0 end        
   
    if oVictim and oVictim:IsAlive() then 
        oVictim:GS2CTriggerPassiveSkill(5133)
    end
    return -30
 end
