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

--怒火

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oBuff)
        OnAddBuff(iPerform, oAction, oBuff)
    end
    oPerformMgr:AddFunction("OnAddBuff", iPerform, func)
end
 
function OnAddBuff(iPerform, oAction, oBuff)
    if not oAction or oAction:IsDead() then
        return
    end
    if not oAction:IsPlayer() then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    if oBuff:Type() ~= gamedefines.BUFF_TYPE.CLASS_ABNORMAL then
        return
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    oAction:AddSP(mExtArg.sp_add or 0)
end

