local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who, target, iCostAmount, mArgs)
    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end

    local oToolMgr = global.oToolMgr
    local iVal = 10000 * iCostAmount
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#gold金币", {item = self:TipsName(), gold = iVal})
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who:RewardGold(iVal,"使用大金币袋",{cancel_tip=1})
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who.m_iPid, sMsg)
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

