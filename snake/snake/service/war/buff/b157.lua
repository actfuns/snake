local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--元婴

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnNewBout(oAction,oBuffMgr)
    if oAction:IsAlive() then
        local lEnemy = oAttack:GetEnemyList()
        local iLen = #lEnemy
        local oVictim = lEnemy[math.random(1,iLen)]
        global.oActionMgr:WarNormalAttack(oAction, oVictim, mArgs)
    end
end
