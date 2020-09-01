local global = require "global"
local skynet = require "skynet"

local virtualbase = import(service_path("item/virtual/virtualbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,virtualbase.CItem)

function CItem:Reward(oPlayer, sReason, mArgs)
    local iValue = self:GetData("Value")
    if not iValue then
        return
    end
    oPlayer.m_oActiveCtrl:RewardEnergy(iValue, sReason, mArgs)
end

function CItem:ValidReward(oPlayer, mArgs)
    mArgs = mArgs or {}
    if oPlayer:GetEnergy() >= oPlayer:GetMaxEnergy() then
        if not mArgs.cancel_tip then
            oPlayer:NotifyMessage(global.oToolMgr:GetTextData(3011))
        end
        return false
    end
    return true
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
