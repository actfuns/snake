local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local pfload = import(service_path("perform/pfload"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--剑令

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAttack, oBuffMgr)
    if not oAttack or oAttack:IsDead() then return end

    local lTarget = oAttack:GetEnemyList()
    local iLen = #lTarget
    if iLen <= 0 then return end

    --灵剑 8308 
    local oVictim = lTarget[math.random(1,iLen)]
    local oPerform = pfload.GetPerform(8308)
    oPerform:Perform(oAttack, {oVictim})
end


