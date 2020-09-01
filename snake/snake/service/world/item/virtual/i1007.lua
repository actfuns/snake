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
    local summid = self:GetData("summid")
    local oSummon
    if summid then
        oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    end
    if not oSummon then
        oSummon = oPlayer.m_oSummonCtrl:GetFightSummon()
    end
    if oSummon then
        oSummon:RewardExp(iValue, sReason, mArgs)
    end
end

function CItem:Clone(iToPlayerId)
    local oNewItem = super(CItem).Clone(self, iToPlayerId)
    oNewItem:SetData("summid", nil)
    return oNewItem
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
