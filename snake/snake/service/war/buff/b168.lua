local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--法力削弱

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local iMaxMp = oAction:GetMaxMp()
    local iSubMp = math.floor(iMaxMp * (1 + self:PerformLevel()/2)/100)
    if iSubMp > 0 then
        oAction:SubMp(iSubMp)
    end
end

