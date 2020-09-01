--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack)
        OnDead(iPerform, oVictim, oAttack)
    end
    oAction:AddFunction("OnDead", self.m_ID, func)
end

function CPerform:CalReviveRatio(oAction)
    local iStrength = oAction:QueryAttr("strength")
    local iRatio = 0
    if iStrength > 0 then
        iRatio = math.floor(20 * (self:GetData("grade", 0) * 2.5 +20) / iStrength)
    end

    iRatio = math.max(15, iRatio)
    iRatio = math.min(25, iRatio)
    return iRatio
end

function OnDead(iPerform, oAction, oAttack)
    if not oAction or oAction:HasKey("revive_disable") then return end
    
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end
    
    local oWar = oAction:GetWar()
    if not oWar then return end

    local iRatio = oPerform:CalReviveRatio(oAction)
    if math.random(100) > iRatio then return end

    local iHP = math.floor(oAction:GetMaxHp() * oPerform:CalSkillFormula() / 100)
    if iHP <= 0 then return end

    oAction:GS2CTriggerPassiveSkill(5117)
    oAction:AddHp(iHP)
    oAction:SendAll("GS2CWarDamage", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        type = 0,
        damage = iHP,
    })

    oWar:AddAnimationTime(1200)
end

