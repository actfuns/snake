local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

-- 野兽幸运 {res_phy_critical_ratio=8}
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oSummon)
        OnAddSummon(iPerform, oAction, oSummon)
    end
    oPerformMgr:AddFunction("OnAddSummon", self.m_ID, func)
end

function OnAddSummon(iPerform, oAction, oSummon)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform or not oSummon then return end

    local sExtArg = oPerform:ExtArg()
    if not sExtArg then return end

    local mEnv = oPerform:SkillFormulaEnv(oAction, nil)
    local mExtArg = formula_string(sExtArg, mEnv)
    for sKey, iValue in pairs(mExtArg) do
        oSummon:Add(sKey, math.floor(iValue))
    end
end
