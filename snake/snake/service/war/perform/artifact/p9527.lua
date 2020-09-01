--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local buffload = import(service_path("buff.buffload"))

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
    oAction:Add("res_poison_ratio", mExtArg.res_poison_ratio)

    local iPerform = self:Type()
    local func = function(oVictim, oAttack, iBuff, iBout)
        return CheckAddBuffBout(iPerform, oVictim, oAttack, iBuff, iBout)
    end
    oPerformMgr:AddFunction("CheckAddBuffBout", iPerform, func)
end

function CheckAddBuffBout(iPerform, oVictim, oAttack, iBuff, iBout)
    if not oVictim or oVictim:IsDead() then
        return 0
    end
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oBuff = buffload.GetBuff(iBuff)
    if oBuff and oBuff:BuffType() == "中毒" then
        return iBout
    end
    return 0
end
