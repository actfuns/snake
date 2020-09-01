--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--敏巧

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    if not oAction:IsPartnerLike() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local iOwner = oAction:GetOwner()
    if not iOwner then return end

    local oWarrior = oWar:GetPlayerWarrior(iOwner)
    if not oWarrior then return end

    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return CalActionHited(iPerform, oAttack, oVictim, oPerform)
    end
    oWarrior:AddFunction("CalActionHited", self.m_ID, func)
end

function CalActionHited(iPerform, oAttack, oVictim, oUsePerform)
    if oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return 0
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    return oPerform:CalSkillFormula(oAttack, oVictim, 100)
end
