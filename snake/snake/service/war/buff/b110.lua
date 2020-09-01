local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff.buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnNewBout(oAction)
    oAction:AddHp(100)
    oAction:SendAll("GS2CWarDamage", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        type = iFlag,
        damage = 100,
    })
end