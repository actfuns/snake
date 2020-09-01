--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--击退

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oUsePerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if oUsePerform then return end
    if not oAttack or not oVictim or oVictim:IsDead() then return end
    if not oVictim:IsNpc() then return end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    if oVictim:GetHp() >= mExtArg.hp_limit then
        return
    end

    if math.random(100) <= mExtArg.ratio then
        global.oActionMgr:DoSubHp(oVictim, oVictim:GetHp(), oAttack)
    end
end
