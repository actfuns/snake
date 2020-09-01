local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--腐蚀术

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        OnSeal(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnSeal", self.m_ID, func)
end

function OnSeal(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end
    
    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio then
        oPerform:Effect_Condition_For_Victim(oVictim, oAttack)
    end
end

