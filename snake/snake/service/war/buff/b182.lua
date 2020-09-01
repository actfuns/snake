local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--修罗咒

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction, oBuffMgr)
    local func = function(oVictim, oAttack, oPerform, iDamage)
        return OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    end
    oBuffMgr:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("OnImmuneDamage", self.m_ID)
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    if not oVictim or not oAttack then return end

    if iDamage <= 0 then return end

    local iRatio = 30
    local iReturnDamage = iRatio * iDamage // 100
    global.oActionMgr:DoSubHp(oAttack, iReturnDamage, oVictim)

    oVictim:AddBoutArgs("immune_damage_ratio", -iRatio)
end
