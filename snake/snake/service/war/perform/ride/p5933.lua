local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--固本培元

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iHp)
        OnDoCureAction(iPerform, oAttack, oVictim, oPerform, iHp)
    end
    oPerformMgr:AddFunction("OnDoCureAction", self.m_ID, func)
end

function OnDoCureAction(iPerform, oAttack, oVictim, oUsePerform, iHp)
    if iHp <= 0 or not oUsePerform then return end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    local iResDrug = oVictim:QueryAttr("res_drug")
    if iResDrug > 0 then
        oVictim:Add("res_drug", math.max(mExtArg.res_drug, -iResDrug))
    end
end

