--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--法术弱点

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return CalMagDefense(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("CalMagDefense", self.m_ID, func)
end

function CalMagDefense(iPerform, oAttack, oVictim, oUsePerform)
    if not oUsePerform then return 0 end

    if oUsePerform:Type() ~= 7202 then return 0 end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    
    local iMagDefense = oVictim:QueryAttr("mag_defense")
    return -math.floor(iMagDefense * mExtArg.res_mag_defense_ratio/100)
end

