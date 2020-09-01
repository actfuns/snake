local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--集中

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    if oVictim then
        mEnv.mag_defense = oVictim:QueryAttr("mag_defense")
    end
    return mEnv
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oAttack or not oVictim then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform or not oUsePerform then return end

    if oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY 
        or oUsePerform:IsGroupPerform() then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    oVictim:Add("mag_defense", -math.floor(mExtArg.sub_mag_defense))
end

