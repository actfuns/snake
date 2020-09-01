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

function CPerform:CalAttackRatio(iAct, oAttack, oVictim)
    local iRatio = 100
    if iAct == 1 then
        iRatio = self.CalSkillFormula(oAttack, oVictim, 100)
    else
        iRatio = formula_string(self:ExtArg(), self:SkillFormulaEnv(oAttack, oVictim))
    end
    return iRatio
end

function CPerform:TurePerform(oAttack, oVictim, iDamageRatio)
    local iAttackCnt = self:GetData("PerformAttackCnt", 1)
    local iRatio = self:CalAttackRatio(iAttackCnt)
    super(CPerform).TurePerform(self, oAttack, oVictim, iRatio)
end