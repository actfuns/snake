local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local pfload = import(service_path("perform/pfload"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--炎盾

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction, oBuffMgr)
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnReceiveDamage(152, oVictim, oAttack, oPerform, iDamage)
    end
    oBuffMgr:AddFunction("OnReceiveDamage", self.m_ID, func)
end

function OnReceiveDamage(iBuff, oVictim, oAttack, oPerform, iDamage)
    if iDamage <= 0 then return end

    local oBuff = oVictim.m_oBuffMgr:HasBuff(iBuff)
    if not oBuff then return end
    
    if not oAttack then return end

    if oAttack:GetHp() <= 0 then return end

    local iSubHp = math.floor(iDamage / 2)
    global.oActionMgr:DoSubHp(oAttack, iSubHp, oVictim)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)

    oBuffMgr:RemoveFunction("OnReceiveDamage", self.m_ID)
end

