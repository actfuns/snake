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

--冲锋

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, iRatio, cmd)
        return OnAddSpeedRatio(iPerform, oAction, iRatio, cmd)
    end
    oPerformMgr:AddFunction("OnAddSpeedRatio", iPerform, func)
end
 
function OnAddSpeedRatio(iPerform, oAction, iRatio, cmd)
    if not oAction or oAction:IsDead() then
        return 0
    end
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio then
        return mExtArg.speed_add_ratio or 0
    end
    return 0
end

