--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or not oVictim then return 0 end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local iRatio = oPerform:CalSkillFormula()
    if (oVictim:GetHp() / oVictim:GetMaxHp() * 100) <= iRatio then
        local sExtArgs = oPerform:ExtArg()
        return formula_string(sExtArgs, oPerform:SkillFormulaEnv())
    end
    return 0
end


-- 嗜血(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

