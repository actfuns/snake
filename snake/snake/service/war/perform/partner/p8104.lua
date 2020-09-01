local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--反手一箭

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(iPerform, oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttacked", self.m_ID, func)
end

function OnAttacked(iPerform, oVictim, oAttack, oUsePerform, iDamage, mArgs)
    if iDamage <= 0 then return end
   
    if mArgs and mArgs.bNotBack then return end

    if not oAttack or oAttack:IsDead() then return end

    local iPfTime
    if oUsePerform then
        if oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
            return
        end
        if oUsePerform:IsGroupPerform() then return end

        if oUsePerform:IsNearAction() then
            iPfTime = 700
        end
    end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oVictim, oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    if math.random(100) <= mExtArg.ratio then
        --global.oActionMgr:Perform(oVictim, oAttack, iPerform, {bNotBack=true})
        global.oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true,hit_back=true,perform_time=iPfTime})
    end
end
