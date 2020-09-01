--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local oBuffMgr = oAction.m_oBuffMgr
    oBuffMgr:SetAttr("ignore_stealth", 1)

    local iRatio = self:CalSkillFormula(oAction, nil, 100)
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(oAttack, oVictim, oPerform, iRatio)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function CPerform:IsActive()
    return false
    -- if self:Level() < 4 then
    --     return false
    -- end
    -- return true
end

function CPerform:CanPerform()
    return false
    -- if self:Level() < 4 then
    --     return false
    -- end
    -- return true
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    if not oVictim then return end

    local oPerformMgr = oVictim.m_oPerformMgr
    local iRatio = self:CalSkillFormula(oAction, nil, 100)
    local func = function (oAtt, oVic, oPerform)
        return OnCalDamageResultRatio(oAtt, oVic, oPerform, iRatio)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
    self:Effect_Condition_For_Victim(oVictim, oAttack)
end

function CPerform:NeedVictimTime()
    return false
end

function OnCalDamageResultRatio(oAttack, oVictim, oPerform, iRatio)
    if not oVictim or not oAttack then return 0 end

    if oAttack:HasKey("ignore_stealth") and oVictim:HasKey("stealth") then
        oAttack:GS2CTriggerPassiveSkill(5129)
        return iRatio or 0
    end

    return 0
end


