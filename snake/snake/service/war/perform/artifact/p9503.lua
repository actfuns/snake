--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--医者之心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return AddCureRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("AddCureRatio", iPerform, func)

    local func1 = function(oAttack, iMP, oUsePerform)
        return CheckResumeMp(iPerform, oAttack, iMP, oUsePerform)
    end
    oPerformMgr:AddFunction("CheckResumeMp", iPerform, func1)
end

function AddCureRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim or oVictim:IsDead() then
        return 0
    end
    if not oAttack or oAttack:IsDead() then
        return 0
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oVictim:IsSummonLike() then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    return mExtArg.add_hp_ratio or 0
end

function CheckResumeMp(iPerform, oAttack, iMP, oUsePerform)
    if not oAttack or oAttack:IsDead() then
        return 0
    end
    if iMP <= 0 then return iMP end

    if not oUsePerform or oUsePerform:ActionType() ~= gamedefines.WAR_ACTION_TYPE.CURE then
        return 0
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    return - math.floor(iMP * mExtArg.resume_mp_ratio / 100)
end

