local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/warbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1001
CItem.m_iLevel = 3
CItem.m_iCalType = 2
inherit(CItem,itembase.CItem)


function CItem:TrueUse(who, target, iCostAmount, mArgs)
    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end

    if who.m_oStateCtrl:GetBaoShiCount() >= who.m_oStateCtrl:GetBaoShiMaxCount() then
        who:NotifyMessage("饱食度已达上限，不能继续使用")
        return
    end

    local iVal = self:CalBaoShi() * iCostAmount
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who.m_oStateCtrl:AddBaoShiCount(iVal, "使用物品")

    local iCnt = who.m_oStateCtrl:GetBaoShiCount()
    local sMsg = global.oToolMgr:GetSystemText({"itemtext"}, 1037, {item = self:TipsName(), amount = iCnt})
    who:NotifyMessage(sMsg)
    return true
end

function CItem:PackWarArgsInfo()
    -- 固定400
    local m = super(CItem).PackWarArgsInfo(self)
    m["hp"] = 400
    return m
end

function CItem:CalBaoShi()
    return 1
end

function CItem:GetTureUseAmount(oPlayer, iAmount)
    iAmount = iAmount or self:GetUseCostAmount()
    local iBaoShi = oPlayer.m_oStateCtrl:GetBaoShiMaxCount() - oPlayer.m_oStateCtrl:GetBaoShiCount()
    local iNeedCnt = math.ceil(iBaoShi/self:CalBaoShi())
    return math.min(iNeedCnt, iAmount)
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    iAmount = self:GetTureUseAmount(oPlayer, iAmount)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end
