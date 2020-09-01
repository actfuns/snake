local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

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

    local iVal = 100 * iCostAmount
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#goldcoin元宝", {item = self:TipsName(), goldcoin = iVal})
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who:RewardByType(gamedefines.MONEY_TYPE.GOLDCOIN, iVal, "使用元宝箱", {cancel_tip=1})
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who.m_iPid, sMsg)
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, sArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end
