--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior, oBuffMgr)
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    end
    oBuffMgr:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)

    oBuffMgr:RemoveFunction("OnImmuneDamage", self.m_ID)
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    if iDamage <= 0 then return end

    if oVictim:IsAlive() and oVictim:GetHp() <= 1 then
        oVictim:SetBoutArgs("immune_damage", 1)
        return
    end
    if oVictim:GetHp() <= iDamage then
        local iPercent = (oVictim:GetHp() - 2) / iDamage * 100 - 100
        oVictim:AddBoutArgs("immune_damage_ratio", iPercent)
        return
    end
end

