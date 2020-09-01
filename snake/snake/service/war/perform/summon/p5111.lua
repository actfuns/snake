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
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oAction:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if oPerform and oUsePerform and oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then 
        local iMinRatio = oPerform:CalMinRatio()
        local iMaxRatio = oPerform:CalMaxRatio()
        return math.random(iMinRatio, iMaxRatio) 
    end
    return 0
end

function CPerform:CalMinRatio()
    return self:CalSkillFormula() - 100
end

function CPerform:CalMaxRatio()
    local sExtArgs = self:ExtArg()
    return formula_string(sExtArgs, self:SkillFormulaEnv()) - 100
end
