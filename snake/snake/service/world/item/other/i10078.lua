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

function CItem:TrueUse(who, target, iCostAmount, mArgs)
    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end

    local mEnv = {SLV=who:GetServerGrade(), grade=who:GetGrade()}
    local iVal = self:CalItemFormula(who, mEnv) * iCostAmount
    assert(iVal > 0, string.format("item use error 10078"))
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#silver银币", {item = self:TipsName(), silver = iVal})
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who:RewardSilver(iVal,"使用大银币袋",{cancel_tip=1})
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who.m_iPid, sMsg)
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end

