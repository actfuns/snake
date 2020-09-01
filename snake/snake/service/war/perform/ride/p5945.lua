local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--反击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(iPerform, oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttacked",self.m_ID, func)
end

function OnAttacked(iPerform, oVictim, oAttack, oUsePerform, iDamage, mArgs)
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform or oVictim:IsDead() then return end
    if not oAttack or oAttack:IsDead() then return end
    if not oAttack:IsVisible(oVictim) then return end    

    if mArgs and mArgs.bNotBack then return end

    if oUsePerform and (oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC 
        or oUsePerform:IsGroupPerform() or not oUsePerform:IsNearAction()) then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oVictim, oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    local iRatio = mExtArg.ratio - oAttack:Query("res_hit_back_ratio", 0)
    if math.random(100) <= iRatio then
        local iAttack = oVictim:QueryAttr("mag_attack") - oVictim:QueryAttr("phy_attack")
        if iAttack > 0 then
            oVictim:AddBoutArgs("phy_attack", iAttack)    
        end
        global.oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true,hit_back=true,perform_time=700})
        if iAttack > 0 then
            oVictim:AddBoutArgs("phy_attack", -iAttack)    
        end
    end
end

