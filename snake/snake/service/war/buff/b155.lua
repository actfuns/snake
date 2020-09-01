local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--妖皇降临

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction,oBuffMgr)
    local iAddHp = 10 + self:PerformLevel() * 10
    local iMaxHp = oAction:GetMaxHp() + iAddHp
    oAction:SetData("max_hp", iMaxHp)

    if oAction:IsAlive() then
        local iHp = oAction:GetHp() + iAddHp
        oAction:SetData("hp", iHp)
    end

    oAction:StatusChange("max_hp", "hp")
end

function CBuff:OnRemove(oAction, oBuffMgr)
    local iAddHp = 10 + self:PerformLevel() * 10
    local iMaxHp = oAction:GetMaxHp() - iAddHp
    oAction:SetData("max_hp", iMaxHp)
    
    local iHp = oAction:GetHp()
    if iHp > iMaxHp then
        oAction:SetData("hp", iMaxHp)
    end
    oAction:StatusChange("max_hp", "hp")
end
