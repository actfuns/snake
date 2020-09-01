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

--影遁

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, iRatio)
        return CheckEscapeRatio(iPerform, oAction, iRatio)
    end
    oPerformMgr:AddFunction("CheckEscapeRatio", iPerform, func)
end

function CheckEscapeRatio(iPerform, oAction, iRatio)
    if not oAction or oAction:IsDead() then
        return 0
    end
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oWar = oAction:GetWar()
    if not oWar then return 0 end

    if oWar:GetWarType() ~= gamedefines.WAR_TYPE.PVE_TYPE then
        return 0
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    return mExtArg.escape_ratio or 0
end
