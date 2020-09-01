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

--神佑

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack)
        OnSubHp(iPerform, oVictim, oAttack)
    end
    oAction:AddFunction("OnSubHp", self.m_ID, func)
end

function OnSubHp(iPerform, oAction, oAttack)
    if not oAction or oAction:IsAlive() then return end

    if oAction:HasKey("revive_disable") then return end
    
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end
    
    local oWar = oAction:GetWar()
    if not oWar then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction, oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)
    
    if math.random(100) <= mExtArg.ratio then
        oAction:GS2CTriggerPassiveSkill(5117)
        oAction:AddHp(mExtArg.hp_add)
        oAction:SendAll("GS2CWarDamage", {
            war_id = oAction:GetWarId(),
            wid = oAction:GetWid(),
            type = 0,
            damage = mExtArg.hp_add,
        })
        oWar:AddAnimationTime(1200)
    end
end
