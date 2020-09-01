local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--反击

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior, oBuffMgr)
    local func = function(oVictim, oAttack, oPerform, iDamge, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs)
    end
    oBuffMgr:AddFunction("OnAttacked", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("OnAttacked", self.m_ID)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs)
    if not oVictim or oVictim:IsDead() then return end

    --普通攻击
    if oPerform then return end

    mArgs = mArgs or {}
    mArgs.bNotBack = true
    mArgs.hit_back = true
    mArgs.perform_time = 700
    global.oActionMgr:WarNormalAttack(oVictim, oAttack, mArgs)
end

