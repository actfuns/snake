local global = require "global"
local skynet = require "skynet"

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

function CItem:TrueUse(who,target)
    local iCostAmount = self:GetUseCostAmount()
    if iCostAmount <= 0 then return end

    local oToolMgr = global.oToolMgr
    local iSid = 11076
    local oItem = global.oItemLoader:GetItem(iSid)
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#item", {item = {self:TipsName(), oItem:TipsName()}})
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    who:RewardItems(iSid, iCostAmount)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who.m_iPid, sMsg)
    return true
end
