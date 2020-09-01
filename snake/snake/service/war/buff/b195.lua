local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction, oBuffMgr)
    self.m_iCnt = 0
    local func = function(oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oBuffMgr:AddFunction("OnAttacked", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("OnAttacked", self.m_ID)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs)
    if iDamage <= 0 then return end

    local oBuff = oVictim.m_oBuffMgr:HasBuff(195)
    if not oBuff then return end

    oBuff.m_iCnt = oBuff.m_iCnt + 1

    if oBuff.m_iCnt >= 2 then 
        oVictim.m_oBuffMgr:RemoveBuff(oBuff)
    end
end
