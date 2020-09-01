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

--咒者之心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)
    oAction:Set("seal_ratio_max", mExtArg.seal_ratio_max)

    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iRatio)
        return OnSealRatio(iPerform, oAttack, oVictim, oPerform, iRatio)
    end
    oPerformMgr:AddFunction("OnSealRatio", iPerform, func)
end

function OnSealRatio(iPerform, oAttack, oVictim, oUsePerform, iRatio)
    if not oVictim or oVictim:IsDead() then
        return 0
    end
    if not oAttack or oAttack:IsDead() then
        return 0
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iAdd = mExtArg.seal_ratio_add or 0
    local iMax = mExtArg.seal_ratio_max
    return (iAdd+iRatio>iMax) and iMax-iRatio or iAdd
end

