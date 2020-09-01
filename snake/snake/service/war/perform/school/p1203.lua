local global = require "global"
local skynet = require "skynet"

local pfobj = import(service_path("perform/pfobj"))

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

function CPerform:CalBuffRatio(oAttack, oVictim)
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs, self:SkillFormulaEnv(oAttack, oVictim))
    return mArgs["buff_effect"]
end

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    local iBuffRatio = 0
    if oVictim and oVictim.m_oBuffMgr:HasBuff(114) then
        iBuffRatio = self:CalBuffRatio(oAttack, oVictim)
    end
    oVictim:SetBoutArgs("cured_ratio", iBuffRatio)
    super(CPerform).TruePerform(self, oAttack,oVictim,iRatio)
    oVictim:SetBoutArgs("cured_ratio", -iBuffRatio)
end

function CPerform:NeedVictimTime()
    return false
end

function CPerform:ChooseAITarget(oAttack)
    local iAITarget = self:GetAITarget()
    local lTarget = self:TargetList(oAttack)
    local oTargetMgr = global.oTargetMgr
    return oTargetMgr:ChooseAITarget(iAITarget, oAttack, lTarget)
end

