--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction,oBuffMgr)
    if oAction:IsDead() then return end

    local iSP = self:GetAttr("sp") or 0
    oAction:AddSP(iSP)
end


