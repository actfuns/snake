--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--回复
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oAttack, oPerform, iDamage)
        OnReceiveDamage(oAction, oAttack, oPerform, iDamage, iPerform)
    end
    oPerformMgr:AddFunction("OnReceiveDamage", iPerform, func)
end

function OnReceiveDamage(oAction, oAttack, oPerform, iDamage, iPerform)
    if iDamage <= 0 then return end

    if not oAction or oAction:IsDead() then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArgs = oPerform:ExtArg()
    local mExtArgs = formula_string(sExtArgs, {})
    if oAction:GetHp() <= oAction:GetMaxHp() * mExtArgs.hp_ratio/100 then
        oAction.m_oBuffMgr:AddBuff(232, 2, {})
    end
end
