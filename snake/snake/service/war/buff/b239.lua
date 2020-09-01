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

    if oPerform and oPerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then
        oVictim:SetBoutArgs("immune_damage", 1)
        oAttack:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = gamedefines.WAR_RECV_DAMAGE_FLAG.IMMUNE,
        })
        return
    end
end

