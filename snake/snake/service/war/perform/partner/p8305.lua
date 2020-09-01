--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--饮血剑

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    if oUsePerform and oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return
    end

    local sArgs = oPerform:ExtArg()
    local mEnv = {level = oPerform:Level()}
    local mArgs = formula_string(sArgs, mEnv)

    local iAddHp = math.floor(iDamage * mArgs.ratio / 100)
    if iAddHp > 0 then
        global.oActionMgr:DoAddHp(oAttack, iAddHp)
    end
end

