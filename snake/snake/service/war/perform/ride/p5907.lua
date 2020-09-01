local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--坚韧

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamaged(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamaged", self.m_ID, func)
end

function OnCalDamaged(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform or not oUsePerform then return 0 end

    if not oUsePerform or oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY then
        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oVictim, oAttack)
        local mExtArg = formula_string(sExtArg, mEnv)
        local iRatio = mExtArg.ratio

        local oPerform5909 = oVictim:GetPerform(5909)
        if oPerform5909 then
            local sExtArg5909 = oPerform5909:ExtArg()
            local mExtArg5909 = formula_string(sExtArg5909, mEnv)
            if oVictim:GetHp() < oVictim:GetMaxHp()*mExtArg5909.hp_ratio//100 then
                iRatio = iRatio + mExtArg5909.ratio
            end
        end

        if math.random(100) <= iRatio then
            return -mExtArg.sub_damage
        end
    end
    
    return 0
end


