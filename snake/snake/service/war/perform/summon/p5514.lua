--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or not oVictim then return end
    if oUsePerform and oUsePerform:IsGroupPerform() then return end 

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAttack:GetWar()
    local iWid = oVictim:GetWid()
    local iBout = oWar:CurBout()

    local mAttr = oAttack:GetExtData("p5514", {})
    local mBout = mAttr[iWid] or {}
    local iCnt = mBout[iBout] or 0
    mBout[iBout] = iCnt + 1
    mAttr[iWid] = mBout
    oAttack:SetExtData("p5514", mAttr)
end

function OnCalDamage(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or not oVictim then return 0 end
    if oUsePerform and oUsePerform:IsGroupPerform() then return 0 end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oWar = oAttack:GetWar()
    local iWid = oVictim:GetWid()
    local iBout = oWar:CurBout()

    local mAttr = oAttack:GetExtData("p5514", {})
    local mBout = mAttr[iWid] or {}
    local iCnt = (mBout[iBout-1] or 0) + (mBout[iBout-2] or 0)
    
    return oPerform:CalSkillFormula(oAttack, oVictim, iCnt)
end


-- 仇恨(天赋)
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
        return OnAttack(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("OnAttack", self.m_ID, func)

    local func2 = function (oAttack, oVictim, oUsePerform)
        return OnCalDamage(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("OnCalDamage", self.m_ID, func2)  
end

function CPerform:SkillFormulaEnv(oAttack, oVictim, iCnt)
    return {grade=oAttack:GetGrade(), att_cnt=iCnt}
end

function CPerform:CalSkillFormula(oAttack, oVictim, iCnt)
    local mInfo = self:GetPerformData()
    local sFormula = mInfo["skill_formula"]
    if not sFormula or sFormula == "" or iCnt <= 0 then
        return 0
    end
    local mEnv = self:SkillFormulaEnv(oAttack, oVictim, iCnt)
    local iResult = math.floor(formula_string(sFormula, mEnv))
    return math.floor(iResult * 100 // 100)
end
