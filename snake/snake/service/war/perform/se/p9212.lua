--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--神佑

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack)
        OnSubHp(iPerform, oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnSubHp", self.m_ID, func)
end

function OnSubHp(iPerform, oVictim, oAttack)
    if not oVictim or oVictim:IsAlive() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
     mEnv.max_hp = oVictim:GetMaxHp()
    local mExtArg = formula_string(sExtArg, mEnv)
    if math.random(100) > mExtArg.ratio then return end

    global.oActionMgr:DoAddHp(oVictim, mExtArg.hp_add)
end

