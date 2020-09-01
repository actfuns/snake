--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oUsePerform)
        return OnCalDamagedResultRatio(iPerform, oAttack, oVictim, oUsePerform) or 0
    end
    oPerformMgr:AddFunction("OnCalDamagedResultRatio", self.m_ID, func)
end

function OnCalDamagedResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim then return end
    if oUsePerform and oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end
    
    local iRatio = oPerform:CalSkillFormula(oVictim, nil, 100, {}, true)
    for _,iPer in pairs({4632, 4635}) do
        local oPer = oVictim:GetPerform(iPer)
        if oPer then
            iRatio = iRatio + oPer:GetTriggerRatio(oVictim)    
        end
    end
    if math.random(100) > iRatio then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iRate = mExtArg.ratio or 0
    local oPerform4633 = oVictim:GetPerform(4633)
    if oPerform4633 then
        iRate = iRate + oPerform4633:GetTriggerValue(oVictim)
    end
    local oPerform4634 = oVictim:GetPerform(4634)
    if oPerform4634 then
        oPerform4634:Effect_Condition_For_Attack(oVictim)
    end
    return -iRate
end
